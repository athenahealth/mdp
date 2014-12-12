#    Copyright 2014 athenahealth, Inc.
#
#   Licensed under the Apache License, Version 2.0 (the "License"); you
#   may not use this file except in compliance with the License.  You
#   may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#   implied.  See the License for the specific language governing
#   permissions and limitations under the License.

"""
This module contains utilities for communicating with the More Disruption Please API.

Classes:
APIConnection -- Connects to the API and performs HTTP requests

Exceptions:
ResponseException -- Raised whenever an API response cannot be parsed
"""

import http.client
import urllib.request
import urllib.parse
import urllib.error
import base64
import json

class ResponseException(Exception):
    """Raised when an API response cannot be decoded from JSON.
    
    Instance variables:
    text -- the body of the HTTP response that could not be decoded
    response -- the HTTP response object
    """
    def __init__(self, text, response):
        self.text = text
        self.response = response
    def __str__(self):
        return '\n{r.status} {r.reason}\n{t}'.format(t = self.text, r = self.response)

class APIConnection(object):
    
    """
    This class abstracts away the HTTP connection and basic authentication from API calls.

    When an object of this class is initialized, it attempts to authenticate to the specified API
    version using the key and secret.  It stores the access token for later use.
    
    Whenever any of the HTTP request methods are called (GET, POST, etc.), the arguments are
    converted to an HTTP request and sent.  The result is decoded from JSON and returned as a dict.
    
    The HTTP request methods take three parameters: a path (string), request parameters (dict), and
    headers (dict).  These methods automatically prepend the specified API verion to the URL.  If
    the practiceid instance variable is set (whether by setting it directly or during
    initialization), it is also added.  Because not all API calls require parameters, and custom
    headers are rare, both of these arguments are optional.
    
    If an API response returns 401 Not Authorized, a new access token is obtained and the request is
    retried.  If a response cannot be decoded from JSON, a ResponseException is raised.
    
    Public methods:
    GET -- Perform an HTTP GET request
    POST -- Perform an HTTP POST request
    PUT -- Perform an HTTP PUT request
    DELETE -- Perform an HTTP DELETE request
    
    Instance variables:
    practiceid -- If set, this will be used as the practiceid parameter to API calls
    """
    
    def __init__(self, version, key, secret, practiceid=None):
        """Connects to the specified API version using key and secret.
        
        If authentication fails due to JSON decoding, this raises a ResponseException. 
        
        Positional arguments:
        version -- the API version to access
        key -- the client key (also known as ID)
        secret -- the client secret
        
        Optional arguments:
        practiceid -- the practice ID to be used in constructing URLs
        """
        auth_prefix_from_version = {
            'v1': '/oauth',
            'preview1': '/oauthpreview',
            'openpreview1': '/oauthopenpreview',
        }
    
        self._host = 'api.athenahealth.com'
        self._version = version.strip('/') 
        self._connection = http.client.HTTPSConnection(self._host)
        self._auth_url = auth_prefix_from_version[self._version]
        self._key = key
        self._secret = secret
        self._authenticate()
        self.practiceid = practiceid
        

    def _authenticate(self):
        # This method authenticates to the API by following the steps of basic authentication.  The
        # URL to use is determined by the version of the API specified in __init__.
        base64string = str(base64.b64encode(bytes('{0}:{1}'.format(self._key, self._secret), 'utf-8')), 'utf-8')
        
        parameters = urllib.parse.urlencode({'grant_type': 'client_credentials'})
        headers = {
            'Content-type': 'application/x-www-form-urlencoded',
            'Authorization': 'Basic {0}'.format(base64string),
        }
        
        path = self._auth_url + '/token'
        
        self._connection.request('POST', path, parameters, headers)
        response = self._connection.getresponse()
        response_text = str(response.read(), 'utf-8')
        
        try:
            authentication = json.loads(response_text)
        except ValueError:
            raise ResponseException(response_text, response)

        self._token = authentication['access_token']
        
    _refresh_authentication = _authenticate
   
    def _call(self, verb, path, parameters, headers, secondcall=False):
        # This method abstracts away the process of adding the authorization token and urlencoding
        # the parameters.  It also converts the API's JSON response into a dict.
        
        body = urllib.parse.urlencode(parameters)
        new_headers = {'Authorization': 'Bearer {0}'.format(self._token)}
        new_headers.update(headers)
        
        # Join '/'-prepended chunks of the URL (with their beginning and ending '/' removed) to
        # create a URL.  This is to prevent strings with extra or missing slashes from combining to
        # create an invalid URL.  Also, if self.practiceid is empty, there's no need to add an extra
        # slash.
        new_path = ''.join('/' + str(part).strip('/') for part in [self._version, self.practiceid, path] if part)
        
        self._connection.request(verb, new_path, body, new_headers)
        try: 
            response = self._connection.getresponse()
            response_text = str(response.read(), 'utf-8')
            return json.loads(response_text)
        except ValueError:
            self._connection = http.client.HTTPSConnection(self._host)
            if response.status == 401 and not secondcall:
                self._refresh_authentication()
                return self._call(verb, path, parameters, headers, secondcall=True)
            else:
                raise ResponseException(response_text, response)
        except http.client.BadStatusLine as e:
            self._connection = http.client.HTTPSConnection(self._host)
            
            if not secondcall:
                self._refresh_authentication()
                return self._call(verb, path, parameters, headers, secondcall=True)
            else:
                raise e
 
    def GET(self, path, parameters=None, headers=None):
        """Perform an HTTP GET request and return a dict of the API response.

        Positional arguments:
        path -- the path (URI) of the resource, as a string
        
        Optional arguments:
        parameters -- the request parameters, as a dict (defaults to None)
        headers -- the request headers, as a dict (defaults to None)
        """
        if not parameters:
            parameters = {}
        if not headers:
            headers = {}
        url = path
        if parameters:
            url += '?' + urllib.parse.urlencode(parameters)
            
        return self._call('GET', url, {}, headers)

    def POST(self, path, parameters=None, headers=None):
        """Perform an HTTP POST request and return a dict of the API response.

        Positional arguments:
        path -- the path (URI) of the resource, as a string
        
        Optional arguments:
        parameters -- the request parameters, as a dict (defaults to None)
        headers -- the request headers, as a dict (defaults to None)
        """
        if not parameters:
            parameters = {}
        new_headers = {'Content-type': 'application/x-www-form-urlencoded'}
        if headers:
            new_headers.update(headers)
        return self._call('POST', path, parameters, new_headers)

    def PUT(self, path, parameters=None, headers=None):
        """Perform an HTTP PUT request and return a dict of the API response.

        Positional arguments:
        path -- the path (URI) of the resource, as a string
        
        Optional arguments:
        parameters -- the request parameters, as a dict (defaults to None)
        headers -- the request headers, as a dict (defaults to None)
        """
        if not parameters:
            parameters = {}
        new_headers = {'Content-type': 'application/x-www-form-urlencoded'}
        if headers:
            new_headers.update(headers)
        return self._call('PUT', path, parameters, new_headers)

    def DELETE(self, path, parameters=None, headers=None):
        """Perform an HTTP DELETE request and return a dict of the API response.

        Positional arguments:
        path -- the path (URI) of the resource, as a string
        
        Optional arguments:
        parameters -- the request parameters, as a dict (defaults to None)
        headers -- the request headers, as a dict (defaults to None)
        """
        url = path
        if parameters:
            url += '?' + urllib.parse.urlencode(parameters)
        if not headers:
            headers = {}
            
        return self._call('DELETE', url, {}, headers)

    def get_token(self):
        """Returns the current access token.""" 
        return self._token
