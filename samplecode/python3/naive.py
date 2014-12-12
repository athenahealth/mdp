#!/usr/bin/env python3

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
This file shows examples of performing More Disruption Please API calls using Python standard
library constructs.  These snippets are good for short sessions where dealing with an API-handling
object would be cumbersome.  It also shows how this can be done if you want more control over URLs
and headers.
"""

import http.client
import base64
import json
import urllib.request
import urllib.parse
import urllib.error

key = 'CHANGEME: YOUR_API_KEY'
secret =  'CHANGEME: YOUR_API_SECRET'
practiceid = 000000
api_version = 'preview1'

# Start a connection
connection = http.client.HTTPSConnection('api.athenahealth.com')


# Authenticate (basic access authentication)
keypair = str(base64.b64encode(bytes('{0}:{1}'.format(key, secret), 'utf-8')), 'utf-8')
auth_parameters = urllib.parse.urlencode({'grant_type': 'client_credentials'})
auth_headers = {
    'Content-type': 'application/x-www-form-urlencoded',
    'Authorization': 'Basic {0}'.format(keypair),
}
auth_prefix_from_version = {
    'v1': '/oauth',
    'preview1': '/oauthpreview',
    'openpreview1': '/oauthopenpreview',
}
auth_path = auth_prefix_from_version[api_version]

connection.request('POST', auth_path, auth_parameters, auth_headers)
response = connection.getresponse()
authentication = json.loads(str(response.read(), 'utf-8'))
token = authentication['access_token']
print(token)

# This token will be used in the header of every other request, so make it in advance.
token_header = {'Authorization': 'Bearer {0}'.format(token)}

# The path for every request has a prefix based on API version and practice ID, so set that now.
base_path = '/{0}/{1}'.format(api_version, practiceid)


# GET /departments
path = base_path + '/departments'

# Make sure to urlencode the parameters so they're escaped properly
parameters = urllib.parse.urlencode({
    'limit': 1,
})
headers = {}
headers.update(token_header)    # Make sure to include the token!

# For GET requests, the parameters go in the URL, not the body, so add them to the URL manually.
# Pass in an empty string for the body (third argument), since GETs don't use it anyway.
connection.request('GET', path + '?' + parameters, '', headers)
response = connection.getresponse()
departments = json.loads(str(response.read(), 'utf-8'))
print(departments)


# POST /appointments/{appointmentid}/notes
appointmentid = 1
path = base_path + '/appointments/{0}/notes'.format(appointmentid)
parameters = urllib.parse.urlencode({
    'notetext': 'Hello from Python3',
})
headers = {
    'Content-Type': 'application/x-www-form-urlencoded',
}
headers.update(token_header)

# POST parameters go in the body
connection.request('POST', path, parameters, headers)
response = connection.getresponse()
post_status = json.loads(str(response.read(), 'utf-8'))
note_successful = post_status['success']
print(note_successful)
