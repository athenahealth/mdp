#!/usr/bin/env python2

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

import httplib
import base64
import json
import urllib

key = 'CHANGEME: YOUR_API_KEY'
secret = 'CHANGEME: YOUR_API_SECRET'
practiceid = 000000
version = 'preview1'

# Start a connection
connection = httplib.HTTPSConnection('api.athenahealth.com')


# Authenticate (basic access authentication)
auth_prefixes = {
	'v1': '/oauth',
	'preview1': '/oauthpreview',
	'openpreview1': '/oauthopenpreview',
}
auth_path = auth_prefixes[version] + '/token'

keypair = base64.b64encode('{0}:{1}'.format(key, secret))
auth_parameters = urllib.urlencode({'grant_type': 'client_credentials'})
auth_headers = {
	'Content-type': 'application/x-www-form-urlencoded',
	'Authorization': 'Basic {0}'.format(keypair),
}
auth_path = auth_path

connection.request('POST', auth_path, auth_parameters, auth_headers)
response = connection.getresponse()
authentication = json.loads(response.read())
token = authentication['access_token']
print token

# This token will be used in the header of every other request, so make it in advance.
token_header = {'Authorization': 'Bearer {0}'.format(token)}

# The path for every request has a prefix based on API version and practice ID, so set that now.
base_path = '/{0}/{1}'.format(version, practiceid)


# GET /departments
path = base_path + '/departments'

# Make sure to urlencode the parameters so they're escaped properly
parameters = urllib.urlencode({
	'limit': 1,
})
headers = {}
headers.update(token_header)	# Make sure to include the token!

# For GET requests, the parameters go in the URL, not the body, so add them to the URL manually.
# Pass in an empty string for the body (third argument), since GETs don't use it anyway.
connection.request('GET', path + '?' + parameters, '', headers)
response = connection.getresponse()
departments = json.loads(response.read())
print departments


# POST /appointments/{appointmentid}/notes
appointmentid = 1
path = base_path + '/appointments/{0}/notes'.format(appointmentid)
parameters = urllib.urlencode({
	'notetext': 'Hello from Python',
})
headers = {
	'Content-Type': 'application/x-www-form-urlencoded',
}
headers.update(token_header)

# POST parameters go in the body
connection.request('POST', path, parameters, headers)
response = connection.getresponse()
post_status = json.loads(response.read())
note_successful = post_status['success']
print note_successful
