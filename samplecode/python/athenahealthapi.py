#    Copyright 2014 athenahealth, Inc.
#
#   Licensed under the Apache License, Version 2.0 (the "License"); you
#   may not use this file except in compliance with the License.  You
#   may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#   implied.  See the License for the specific language governing
#   permissions and limitations under the License.

"""
This module contains utilities for communicating with the More Disruption Please API.
"""

import httplib
import urllib
import urlparse
import base64
import json

class APIConnection(object):
	
	"""
	This class abstracts away the HTTP connection and basic authentication from API calls.

	When an object of this class is initialized, it attempts to authenticate to the specified API
	version using the key and secret.  It stores the access token for later use.
	
	Whenever any of the HTTP request methods are called (GET, POST, etc.), the arguments are
	converted to an HTTP request and sent.	The result is decoded from JSON and returned as a dict.
	
	The HTTP request methods take three parameters: a path (string), request parameters (dict), and
	headers (dict).	 These methods automatically prepend the specified API verion and the practiceid
	(if set) to the URL.  Because not all API calls require parameters, and custom headers are rare,
	both of these arguments are optional.
	
	If an API response returns 401 Not Authorized, a new access token is obtained and the request is
	retried.
	
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
		
		self._version = version
		self._key = key
		self._secret = secret
		self.practiceid = practiceid

		self._host = 'api.athenahealth.com'
		self._connection = httplib.HTTPSConnection(self._host)

		self._authenticate()
		

	def _authenticate(self):
		# This method authenticates to the API by following the steps of basic authentication.	The
		# URL to use is determined by the version of the API specified in __init__.
		auth_prefixes = {
			'v1': '/oauth',
			'preview1': '/oauthpreview',
			'openpreview1': '/oauthopenpreview',
		}
		path = path_join(auth_prefixes[self._version], '/token')
		
		auth = base64.b64encode('{0}:{1}'.format(self._key, self._secret))
		
		parameters = {'grant_type': 'client_credentials'}

		headers = {
			'Content-type': 'application/x-www-form-urlencoded',
			'Authorization': 'Basic {0}'.format(auth),
		}

		response = self._call('POST', path, parameters, headers)
		
		self._token = response['access_token']
		
	_refresh_authentication = _authenticate

	def _refresh_connection(self):
		self._connection = httplib.HTTPSConnection(self._host)
   
	def _call(self, verb, path, body, headers):
		self._connection.request(verb, path, urllib.urlencode(body), headers)
		response = self._connection.getresponse()
		content = response.read()
		return json.loads(content)

	def _authorized_call(self, verb, path, body, headers, retry=True):
		new_path = path_join(self._version, self.practiceid, path)

		new_headers = {'Authorization': 'Bearer {0}'.format(self._token)}
		new_headers.update(headers)
		
		try:
			return self._call(verb, new_path, body, new_headers)
		except (ValueError, httplib.BadStatusLine) as e:
			self._refresh_connection()
			self._refresh_authentication()
			if retry:
				return self._authorized_call(verb, path, body, headers, retry=False)
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
			url += '?' + urllib.urlencode(parameters)
			
		return self._authorized_call('GET', url, {}, headers)

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
		return self._authorized_call('POST', path, parameters, new_headers)

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
		return self._authorized_call('PUT', path, parameters, new_headers)

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
			url += '?' + urllib.urlencode(parameters)
		if not headers:
			headers = {}
		return self._authorized_call('DELETE', url, {}, headers)

	def get_token(self):
		"""Returns the current access token."""
		return self._token

def path_join(*parts):
	# Join '/'-prepended chunks of the URL (with '/' trimmed off) to create a URL.
	return ''.join('/' + str(part).strip('/') for part in parts if part)
