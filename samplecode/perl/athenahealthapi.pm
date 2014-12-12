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

=head1 athenahealthapi

This class abstracts away the HTTP connection and basic authentication from API calls.

When an object of this class is constructed, it attempts to authenticate using the key, secret, and
version specified.  It stores the access token for later use.

Whenever any of the HTTP request methods are called (GET, POST, etc.), the arguments are converted
into the proper form for the request.  The result is decoded from JSON and returned as a hashref.

The HTTP request methods take three parameters: a path (string), request parameters (hashref), and
headers (hashref).  These methods automatically prepend the specified API version and practiceid (if
set) to the URL.  Because not all API calls require parameters and custom headers are rare, both of
those arguments are optional.

If an API call results in an error, a new access token is obtained and the request is retried.

=cut

package athenahealthapi;

use strict;
use warnings;
no warnings 'uninitialized';

use LWP;
use JSON;
use URI::Escape;

=head2 new
    
Takes a hashref with the following structure

 {
  version => the API version to access,
  key => the client key (also known as ID),
  secret => the client secret,
  practiceid => the practiceid to use when constructing calls (optional),
 }

=cut
    
sub new {
    my ($class, $version, $key, $secret, $practiceid) = @_;
    
    my $self = {
        host => 'https://api.athenahealth.com/',
        version => $version,
        key => $key,
        secret => $secret,
        useragent => LWP::UserAgent->new(),
        token => '',
    };
    
    bless($self, $class);
    
    $self->_authenticate();
    
    if (defined($practiceid)) {
        $self->{practiceid} = $practiceid;
    }
    
    return $self;
}

sub _authenticate {
    # Authenticate to the API (using basic authentication) with the version, key, and secret from
    # initialization.
    my ($self) = @_;
    
    # We need the proper grant_type to receive an access_token.
    my $params = {
        'grant_type' => 'client_credentials',
    };
    
    # Create a new set of headers and add the basic auth header.
    my $headers = HTTP::Headers->new();
    $headers->authorization_basic($self->{key}, $self->{secret});
    
    my $authurls = {
        'v1' => 'oauth',
        'preview1' => 'oauthpreview',
        'openpreview1' => 'oauthopenpreview',
    };
    
    # Join up a URL, and make sure the parameters are properly escaped.
    my $url = url_join($self->{host}, $authurls->{$self->{version}}, '/token');
    my $safe_params = url_safe($params);
    
    # Create a new request and set the content-type
    my $req = HTTP::Request->new('POST', $url, $headers, $safe_params);
    $req->content_type('application/x-www-form-urlencoded');
    
    # Prepare, send, and decode the request.
    $self->{useragent}->prepare_request($req);
    my $res = $self->{useragent}->send_request($req);
    my $decoded = decode_json($res->content());
    
    $self->{token} = $decoded->{access_token};
}

=head2 GET
    
Perform an HTTP GET request and return a hashref of the converted response.

Takes a hashref of the following structure:
	
 {
  path => the path (URI) of the resource as a string,
  params => the request parameters as a hashref (optional),
  headers => the request headers as a hashref (optional),
 }

=cut
    
sub GET {
    my ($self, $args) = @_;
    
    my $path  = $args->{path} || '';
    my $params = $args->{params} || {};
    my $headers = $args->{headers} || {};
    
    my $url = url_join($self->{host}, $self->{version}, $self->{practiceid}, $path) . '?' . url_safe($params);
    
    my $blessed_headers = HTTP::Headers->new(%$headers);
    my $req = HTTP::Request->new('GET', $url, $blessed_headers, url_safe({}));
    
    return $self->_authorized_call($req);
}

=head2 POST
    
Perform an HTTP POST request and return a hashref of the converted response.

Takes a hashref of the following structure:
	
 {
  path => the path (URI) of the resource as a string,
  params => the request parameters as a hashref (optional),
  headers => the request headers as a hashref (optional),
 }

=cut
    
sub POST {
    my ($self, $args) = @_;
    
    my $path = $args->{path} || '';
    my $params = $args->{params} || {};
    my $headers = $args->{headers} || {};
        
    my $url = url_join($self->{host}, $self->{version}, $self->{practiceid}, $path);
    
    my $blessed_headers = HTTP::Headers->new(%$headers);
    my $req = HTTP::Request->new('POST', $url, $blessed_headers, url_safe($params));
    $req->content_type('application/x-www-form-urlencoded');
    
    return $self->_authorized_call($req);
}

=head2 PUT
    
Perform an HTTP PUT request and return a hashref of the converted response.

Takes a hashref of the following structure:
	
 {
  path => the path (URI) of the resource as a string,
  params => the request parameters as a hashref (optional),
  headers => the request headers as a hashref (optional),
 }

=cut
    
sub PUT {
    my ($self, $args) = @_;
    
    my $path = $args->{path} || '';
    my $params = $args->{params} || {};
    my $headers = $args->{headers} || {};
    
    my $url = url_join($self->{host}, $self->{version}, $self->{practiceid}, $path);
    
    my $blessed_headers = HTTP::Headers->new(%$headers);
    my $req = HTTP::Request->new('PUT', $url, $blessed_headers, url_safe($params));
    $req->content_type('application/x-www-form-urlencoded');
    
    return $self->_authorized_call($req);    
}

=head2 DELETE
    
Perform an HTTP DELETE request and return a hashref of the converted response.

Takes a hashref of the following structure:
	
 {
  path => the path (URI) of the resource as a string,
  params => the request parameters as a hashref (optional),
  headers => the request headers as a hashref (optional),
 }

=cut
    
sub DELETE {
    my ($self, $args) = @_;
    
    my $path = $args->{path} || '';
    my $params = $args->{params} || {};
    my $headers = $args->{headers} || {};
    
    my $url = url_join($self->{host}, $self->{version}, $self->{practiceid}, $path) . '?' . url_safe($params);
    
    my $blessed_headers = HTTP::Headers->new(%$headers);
    my $req = HTTP::Request->new('DELETE', $url, $blessed_headers, url_safe({}));
    
    return $self->_authorized_call($req);    
}    

=head2 get_token

Returns the current access token.

=cut
    
sub get_token {
    my ($self) = @_;
    return $self->{token};
}


sub _authorized_call {
    # This method abstracts away adding the authorization header to requests.
    
    my ($self, $req, $secondcall) = @_;
    $req->header('Authorization' => 'Bearer ' . $self->{token});
    $self->{useragent}->prepare_request($req);
    my $res = $self->{useragent}->send_request($req);
    
    if ($res->is_error && !defined($secondcall)) {
        $self->_authenticate();
        return $self->_authorized_call($req, 1);
    }
    
    return decode_json($res->content);
}

=head2 url_safe

Converts a parameters hashref into a URL-safe string.
    
Takes a hashref containing key-value pairs of request parameters.

=cut
    
sub url_safe {
    my ($args) = @_;
    return join('&', map {
        uri_escape($_) . '=' . uri_escape($args->{$_})
    } keys %$args);
}

=head2 url_join
    
Joins parts of a URL into a valid URL string.

Takes any number of arguments.

=cut
    
sub url_join {
    my @args = @_;
    for (@args) {
        s{^/+}{};                # strip off leading slashes
        s{/+$}{};                # strip off trailing slashes
    }
    return join('/', @args);
}

1;
