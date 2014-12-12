#!/usr/bin/env php
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
 * This file shows examples of performing More Disruption Please API calls using stardard PHP
 * constructs.  These snippets are good for short sessions where dealing with an API-handling object
 * would be cumbersome.  It also shows how this can be done if you want more control over URLs and
 * headers.
 */

$key = 'CHANGEME: YOUR_API_KEY';
$secret = 'CHANGEME: YOUR_API_SECRET';
$version = 'preview1';
$practiceid = 000000;

# Small abstraction because typing this out is a pain.
function call($verb, $url, $parameters, $headers) {
    $context = stream_context_create(array(
        'http' => array(
            'method' => $verb,
            'header' => $headers,
            'content' => http_build_query($parameters)
        )
    ));
    return file_get_contents($url, false, $context);
}

# Authenticate
$auth = call(
    'POST',
    'https://api.athenahealth.com/oauthpreview/token', 
    array(
        'grant_type' => 'client_credentials'
    ), 
    array(
        'Authorization: Basic ' . base64_encode("$key:$secret"),
        'Content-type: application/x-www-form-urlencoded'
    )
);
$auth_response = json_decode($auth, true);

# Store the token for later.
$token = $auth_response['access_token'];
echo $token . "\n";

# Set up our authorization header since we'll need it later
$token_header = array('Authorization: Bearer ' . $token);

# GET /customfields
$url = "https://api.athenahealth.com/$version/$practiceid/customfields";
$headers = array_merge($token_header, array());
$r = call('GET', $url, array(), $headers);
print_r(json_decode($r, true));

# GET /deparments
$s = call(
    'GET',
    "https://api.athenahealth.com/$version/$practiceid/departments",
    array(
        'showalldepartments' => 'false',
        'showproviders' => 'false'),
    $headers
);
print_r(json_decode($s, true));

# POST /appointments/1/notes
$headers = array_merge($token_header, array('Content-type: application/x-www-form-urlencoded'));
$t = call(
    'POST',
    "https://api.athenahealth.com/$version/$practiceid/appointments/1/notes",
    array(
        'notetext' => 'once more'
    ),
    $headers
);
print_r(json_decode($t, true));

?>