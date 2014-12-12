#!/usr/bin/env perl

#   Copyright 2014 athenahealth, Inc.
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

use strict;
use warnings;

use LWP;
use JSON;
use Data::Dumper;
use URI::Escape;

# Setup all the constants
my $practiceid = 000000;
my $version = 'preview1';
my $key = 'CHANGEME: YOUR_API_KEY';
my $secret = 'CHANGEME: YOUR_API_SECRET';
my $authurl = 'https://api.athenahealth.com/oauthpreview/token';

# Make a new user agent to make requests through
my $useragent = LWP::UserAgent->new();

# Authentication parameters and headers
my $parameters = 'grant_type=client_credentials';
my $headers = HTTP::Headers->new();
$headers->authorization_basic($key, $secret);

# Make a new POST request, set the parameters, headers, and content-type
my $req = HTTP::Request->new('POST', $authurl, $headers, $parameters);
$req->content_type('application/x-www-form-urlencoded');

# Prepare and send
$useragent->prepare_request($req);
my $res = $useragent->send_request($req);

# Decode from JSON and save the token for later
my $decoded = decode_json($res->content);
my $token = $decoded->{'access_token'};

print "$token\n";

my $baseurl = 'https://api.athenahealth.com/';


# GET /customfields
my $url2 = $baseurl . $version . '/' . $practiceid . '/customfields';

# Add in the Authorization header with the token
my $req2 = HTTP::Request->new('GET', $url2);
$req2->header('Authorization' => 'Bearer ' . $token);
$useragent->prepare_request($req2);
print(Dumper $req2);

my $res2 = $useragent->send_request($req2);
my $customfields = decode_json($res2->content);
print Dumper($customfields);


# GET /departments
my %params = (
	'limit' => 1,
);
	
# GETs take parameters in the URL.  This escapes and joins everything properly.
my $query = join('&', map { 
	uri_escape($_) . '=' . uri_escape($params{$_}) 
} keys(%params));

if ($query) {
	$query = '?' . $query;
}

my $url3 = $baseurl . $version . '/' . $practiceid . '/departments';
my $req3 = HTTP::Request->new('GET', $url3 . $query);
$req3->header('Authorization' => 'Bearer ' . $token);
$useragent->prepare_request($req3);
my $res3 = $useragent->send_request($req3);

my $departments = decode_json($res3->content);
