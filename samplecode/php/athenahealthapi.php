<?php
/*
   Copyright 2014 athenahealth, Inc.

   Licensed under the Apache License, Version 2.0 (the "License"); you
   may not use this file except in compliance with the License.  You
   may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
   implied.  See the License for the specific language governing
   permissions and limitations under the License. 
*/

/**
 * This module contains utilities for communicating with the More Disruption Please API.
 * @package athenahealthapi
 */

/**
 * This class abstracts away the HTTP connection and basic authentication from API calls.
 * 
 * When an object of this class is constructed, it attempts to authenticate (using basic
 * authentication) at https://api.athenahealth.com/ using the key, secret, and version specified.
 * It stores the access token for later use.
 * 
 * Whenever any of the HTTP request methods are called (GET, POST, etc.), the arguments are
 * converted into the proper form for the request.  The result is decoded from JSON and returned as
 * an array.
 * 
 * The HTTP request methods take three parameters: a path (string), request parameters (array), and
 * headers (array).  These methods automatically prepend the API version and practiceid (if set) to
 * the URL.  Because not all API calls require parameters and custom headers are rare, both of those
 * arguments are optional.
 *
 * If an API response returns 401 Not Authorized, a new access token is obtained and the request is
 * retried.
 */
class APIConnection {
    public $practiceid;
    
    private $version;
    private $key;
    private $secret;
    private $baseurl;
    private $auth_url;
    private $token;
    private $refresh_token;
    
    /**
     * Connects to the host, authenticates to the specified API version using key and secret.
     *
     * @param string $version the specified API version to access
     * @param string $key the client key (also known as ID)
     * @param string $secret the client secret
     * @param string|int $practiceid|null the practice ID to be used in requests (optional)
     */
    public function __construct($version, $key, $secret, $practiceid=null) {
        $this->version = $version;
        $this->key = $key;
        $this->secret = $secret;
        $this->practiceid = $practiceid;
        $this->baseurl = 'https://api.athenahealth.com/' . $this->version;
        
        $auth_prefixes = array(
            'v1' => 'oauth/token',
            'preview1' => 'oauthpreview/token',
            'openpreview1' => 'ouathopenpreview/token',
        );
        $this->authurl = 'https://api.athenahealth.com/' . $auth_prefixes[$this->version];
        
        $this->authenticate();
    }
    
    private function authenticate() {
        # This method is for internal use.  It performs the authentication process by following the
        # steps of basic authentication.  The URL to authenticate to is determined by the version of
        # the API specified at construction.
        $url = $this->authurl;
        $parameters = array('grant_type' => 'client_credentials');
        $headers = array(
            'Content-type' => 'application/x-www-form-urlencoded',
            'Authorization' => 'Basic ' . base64_encode($this->key . ':' . $this->secret),
        );
        
        $authorization = $this->call('POST', $url, $parameters, $headers);
        
        $this->token = $authorization['access_token'];
        $this->refresh_token = $authorization['refresh_token'];
    }
    
    /**
     * This method abstracts away the process of using stream contexts and file_get_contents for the
     * API calls.  It also does JSON decoding before return.
     *
     * @access private
     */
    private function call($verb, $url, $body, $headers, $secondcall=false) {
        # It's easier to specify headers as an associative array, but making it a context requires
        # everything to be in the values of an indexed array.
        $formatted_headers = array();
        foreach ($headers as $k => $v) {
            $formatted_headers[] = $k . ': ' . $v;
        }
        
        # We shouldn't always be ignoring errors, but if we're calling this a second time, it's
        # because we found errors we want to ignore.  So we set ignore_errors to be the same as
        # $secondcall.
        $context = stream_context_create(array(
            'http' => array(
                'method' => $verb,
                'header' => $formatted_headers,
                'content' => http_build_query($body),
                'ignore_errors' => $secondcall,
            )
        ));
        # NOTE: The warnings in file_get_contents are suppressed because the MDP API returns HTTP
        # status codes other than 200 (like 401 and 400) with information in the body that provides
        # a much better explanation than the code itself.
        $contents = @file_get_contents($url, false, $context);
        
        # $contents is false if there was an error, so if it was a 401 Not Authorized, propogate the
        # false.  Otherwise, try it again with ignored errors.
        if ($contents === false) {
            $response_headers = http_parse_headers(implode("\r\n", $http_response_header));
            $response_code = $response_headers['Response Code'];
            if ($response_code === 401) {
                return false;
            }
            if (!$secondcall) {
                return $this->call($verb, $url, $body, $headers, $secondcall=true);
            }
        }
        
        return json_decode($contents, true); 
    }
    
    /**
     * This method abstracts away adding the authorization header to requests.
     *
     * @access private
     */
    private function authorized_call($verb, $url, $body, $headers, $secondcall=false) {
        $auth_header = array('Authorization' => 'Bearer ' . $this->token);
        $response = $this->call($verb, $url, $body, array_merge($auth_header, $headers));
        
        # $response is false if we had a 401 Not Authorized, so re-authenticate and try again.
        if ($response === false && !$secondcall) {
            $this->authenticate();
            return $this->authorized_call($verb, $url, $body, $headers, $secondcall=true);
        }
        
        return $response;
    }
    

    /**
     * This method joins together parts of a URL to make a valid one.
     *
     * Trims existing slashes from arguments and re-joins them with slashes.
     * 
     * @param string $arg,... any number of strings to join
     *
     * @access private
     */
    private function url_join() {
        return join('/', array_map(function ($p) {
            return trim($p, '/');
        }, array_filter(func_get_args(), function($value){
                return ! (is_null($value) || $value == '');
            }
        )));
    }
    
    /**
     * Perform at HTTP GET request and return an associative array of the API response.
     *
     * @param string $url the path (URI) of the resource
     * @param mixed array $parameters|null the request parameters
     * @param mixed array $headers|null the request headers
     */
    public function GET($url, $parameters=null, $headers=null) {
        $new_parameters = array();
        if ($parameters) {
            $new_parameters = array_merge($new_parameters, $parameters);
        }
        
        $new_headers = array();
        if ($headers) {
            $new_headers = array_merge($new_headers, $headers);
        }
        
        # Join up a URL and add the parameters, since GET requests require parameters in the URL.
        $new_url = $this->url_join($this->baseurl, $this->practiceid, $url);
        if ($new_parameters) {
            $new_url .= '?' . http_build_query($new_parameters);
        }
        
        return $this->authorized_call('GET', $new_url, array(), $new_headers);
    }
    
    /**
     * Perform at HTTP POST request and return an associative array of the API response.
     *
     * @param string $url the path (URI) of the resource
     * @param mixed array $parameters|null the request parameters
     * @param mixed array $headers|null the request headers
     */
    public function POST($url, $parameters=null, $headers=null) {
        $new_parameters = array();
        if ($parameters) {
            $new_parameters = array_merge($new_parameters, $parameters);
        }
        
        # Make sure POSTs have the proper headers
        $new_headers = array(
            'Content-type' => 'application/x-www-form-urlencoded',
        );
        if ($headers) {
            $new_headers = array_merge($new_headers, $headers);
        }
        
        # Join up a URL
        $new_url = $this->url_join($this->baseurl, $this->practiceid, $url);
        
        return $this->authorized_call('POST', $new_url, $new_parameters, $new_headers);
    }
    
    /**
     * Perform at HTTP PUT request and return an associative array of the API response.
     *
     * @param string $url the path (URI) of the resource
     * @param mixed array $parameters|null the request parameters
     * @param mixed array $headers|null the request headers
     */
    public function PUT($url, $parameters=null, $headers=null) {
        $new_parameters = array();
        if ($parameters) {
            $new_parameters = array_merge($new_parameters, $parameters);
        }
        
        # Make sure PUTs have the proper headers
        $new_headers = array(
            'Content-type' => 'application/x-www-form-urlencoded',
        );
        if ($headers) {
            $new_headers = array_merge($new_headers, $headers);
        }
        
        # Join up a URL
        $new_url = $this->url_join($this->baseurl, $this->practiceid, $url);
        
        return $this->authorized_call('PUT', $new_url, $new_parameters, $new_headers);
    }
    
    /**
     * Perform at HTTP DELETE request and return an associative array of the API response.
     *
     * @param string $url the path (URI) of the resource
     * @param mixed array $parameters|null the request parameters
     * @param mixed array $headers|null the request headers
     */
    public function DELETE($url, $parameters=null, $headers=null) {
        $new_url = $this->url_join($this->baseurl, $this->practiceid, $url);
        if ($parameters) {
            $new_url .= '?' . http_build_query($parameters);
        }
        
        $new_headers = array();
        if ($headers) {
            $new_headers = array_merge($new_headers, $headers);
        }
        
        return $this->authorized_call('DELETE', $new_url, array(), $new_headers);    
    }
    
    /**
     * Returns the current access_token.
     */
    public function get_token() {
        return $this->token;
    }
}
   
?>
