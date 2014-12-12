//	  Copyright 2014 athenahealth, Inc.
//
//	 Licensed under the Apache License, Version 2.0 (the "License"); you
//	 may not use this file except in compliance with the License.  You
//	 may obtain a copy of the License at
//
//		 http://www.apache.org/licenses/LICENSE-2.0
//
//	 Unless required by applicable law or agreed to in writing, software
//	 distributed under the License is distributed on an "AS IS" BASIS,
//	 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
//	 implied.  See the License for the specific language governing
//	 permissions and limitations under the License.

var events = require('events')
var https = require('https')
var querystring = require('querystring')


// Useful for making optional arguments look cleaner
function optional(arg, fallback) {
	return (arg !== void 0) ? arg : fallback
}

// Useful for combining two objects. This does not mutate either argument. If the arguments share
// keys, the values from the second object are used.
function merge(obj1, obj2) {
	var out = {}
	for (var attr in obj1) {
		out[attr] = obj1[attr]
	}
	for (var attr in obj2) {
		out[attr] = obj2[attr]
	}
	return out
}

// A convenient way to create clean paths without having to worry about slashes.
function path_join() {
	// trim slashes from arguments, prefix a slash to the beginning of each, re-join (ignores empty parameters)
	var args = Array.prototype.slice.call(arguments, 0)
	var nonempty = args.filter(function(arg, idx, arr) {
		return typeof(arg) != 'undefined'
	})
	var trimmed = nonempty.map(function(arg, idx, arr) {
		return '/' + String(arg).replace(new RegExp('^/+|/+$'), '')
	})
	return trimmed.join('')
}

/**
 * This class abstracts away the HTTP connection and basic authentication from API calls.
 *
 * When an object of this class is constructed, it attempts to authenticate (using basic
 * authentication) using the key, secret, and version specified. It stores the access token for
 * later use.
 *
 * Whenever any of the HTTP request methods are called (GET, POST, etc.), the arguments are
 * converted into the proper form for the request. The result is decoded from JSON and returned.
 *
 * The HTTP request methods take a mandatory path parameter (string) and an optional options
 * parameter (object). The API version associated with this connection is automatically prepended to
 * the path, as is the practice ID (if set). These methods return event emitters that emit 'done'
 * and 'error' events.
 *
 * If an API call returns 401 Not Authorized, a new access token is obtained and the request is
 * retried once.
 *
 * @class
 * @param {string} version - Version of the API to access
 * @param {string} key - Client API key (also known as ID)
 * @param {string} version - Client API version
 * @param {string|number} [practiceid=''] - Practice ID to use
 *
 * @requires module:events
 * @requires module:https
 * @requires module:querystring
 */
function Connection(version, key, secret, practiceid) {
	// Private variables
	var _version = ''
	var _key = ''
	var _secret = ''
	var _token = ''
	var _hostname = 'api.athenahealth.com'

	/**
	 * The practice ID to use when sending requests.
	 * @member {string|number} practiceid
	 */
	this.practiceid = void 0

	function __construct(self) {
		_version = version
		_key = key
		_secret = secret
		self.practiceid = optional(practiceid, void 0)
		self.status = authenticate()
	}

	/**
	 * Performs basic access authentication to the API.
	 *
	 * The returned emitter emits 'done' on success and 'error' on failure.
	 *
	 * @private
	 * @returns {events.EventEmitter}
	 */
	var authenticate = function() {
		var emitter = new events.EventEmitter

		var auth_prefixes = {
			v1: '/oauth',
			preview1: '/oauthpreview',
			openpreview1: '/oauthopenpreview',
		}

		// Set up the request
		var verb = 'POST'
		var path = path_join(auth_prefixes[_version], '/token')
		var params = querystring.stringify({grant_type: 'client_credentials'})
		var headers = {
			'authorization': 'Basic ' + new Buffer(_key + ':' + _secret).toString('base64'),
			'content-type': 'application/x-www-form-urlencoded',
			'content-length': params.length,
		}

		// Make the request and propagate the events, storing the token for later
		call(verb, path, params, headers, false)
			.on('done', function(response) {
				_token = response.access_token
				emitter.emit('ready')
			}).on('error', function(error) {
				emitter.emit('error', error)
			})

		return emitter
	}

	/**
	 * This method abstracts away formatting the request and decoding the JSON of an API call.
	 *
	 * If retry is true, receiving a 401 will cause the returned emitter to emit a '401' event.
	 * Otherwise, we will attempt to decode it anyway.
	 *
	 * Events
	 * 401 - If retry is true and a 401 is received
	 * done (output) - Response was received and decoded. Decoded JSON is placed in output.
	 * error (error) - An error occurred in making this request. The error is placed in error.
	 *
	 * @private
	 * @param {string} verb - HTTP method
	 * @param {string} path - Path portion of URL
	 * @param {string} body - Request body
	 * @param {object} headers - Request headers in key-value form
	 * @param {boolean} retry - If true, emit the 401 event when appropriate, otherwise ignore 401s.
	 * @returns {events.EventEmitter}
	 */
	var call = function(verb, path, body, headers, retry) {
		var emitter = new events.EventEmitter
		var output

		var req = https.request({
			hostname: _hostname,
			method: verb,
			path: path,
			headers: headers,
		}, function(response) {
			if (response.statusCode == 401 && retry) {
				emitter.emit('401')
			}
			else {
				response.setEncoding('utf8')
				var content = ''
				response.on('data', function(data) {
					content += data
				})
				response.on('end', function() {
					try {
						output = JSON.parse(content)
						emitter.emit('done', output)
					}
					catch (e) {
						e.cause = content
						emitter.emit('error', e)
					}
				})
			}
		})

		req.on('error', function(e) {
			emitter.emit('error', e)
		})

		req.write(body)
		req.end()

		return emitter
	}

	/**
	 * This method adds extra required headers and path elements to calls that require
	 * authorization. If a 401 is received, retry once.
	 *
	 * @private
	 * @param {string} verb - HTTP method
	 * @param {string} path - Path portion of URL (omitting version and practiceid)
	 * @param {object} body - Request body in key-value form
	 * @param {object} headers - Request headers in key-value form
	 * @returns {events.EventEmitter}
	 */
	var authorized_call = function(verb, path, body, headers) {
		var emitter = new events.EventEmitter

		var new_path = path_join(_version, practiceid, path)
		var new_body = querystring.stringify(body)
		var new_headers = merge({
			'authorization': 'Bearer ' + _token,
			'content-length': new_body.length,
		}, headers)

		// This is a little hack to get authorized calls to retry when we get a 401 Not Authorized.
		// Since this is Javascript, we can't wait for the second `call` in order to return. To
		// achieve this, the emitter from `call` emits a '401' event only when its last argument
		// (retry) is true. Then we need to re-auth (which itself returns an emitter), and when
		// that's ready, we can try again. This time we tell `call` to ignore 401s (by telling it we
		// won't retry). I think this can be done better with promises at some point, but that may
		// require an external library or waiting until ECMA6 gets implemented by node.
		call(verb, new_path, new_body, new_headers, true)
			.on('401', function() {
				authenticate()
					.on('ready', function() {
						// Since we can't just do this recursively (due to emitter returns), we have
						// to re-set the auth header manually.
						new_headers['authorization'] = 'Bearer ' + _token

						call(verb, new_path, new_body, new_headers, false)
							.on('done', function(response) {
								emitter.emit('done', response)
							})
							.on('error', function(error) {
								emitter.emit('error', error)
							})
					})
			})
			// These handlers will not execute if we get a 401, because `call` is set up that way.
			.on('done', function(response) {
				emitter.emit('done', response)
			})
			.on('error', function(error) {
				emitter.emit('error', error)
			})

		return emitter
	}


	/**
	 * Perform a GET request.
	 *
	 * Events
	 * done (response) - The decoded JSON object will be stored in response
	 * error (error) - The error will be stored in error
	 *
	 * @param {string} path - The path of the API call
	 * @param {object} [options={}] - Additional call options
	 * @param {object} [options.params={}] - Request parameters
	 * @param {object} [options.headers={}] - Additional request headers
	 * @returns {event.EventEmitter}
	 */
	this.GET = function(path, options) {
		var extra = optional(options, {})
		var params = optional(extra.params, {})
		var headers = optional(extra.headers, {})

		// In a GET request, params go in the URL
		var query = querystring.stringify(params)
		var new_path = path
		if (query) {
			new_path += '?' + query
		}

		return authorized_call('GET', new_path, {}, headers)
	}

	/**
	 * Perform a POST request.
	 *
	 * Events
	 * done (response) - The decoded JSON object will be stored in response
	 * error (error) - The error will be stored in error
	 *
	 * @param {string} path - The path of the API call
	 * @param {object} [options={}] - Additional call options
	 * @param {object} [options.params={}] - Request parameters
	 * @param {object} [options.headers={}] - Additional request headers
	 * @returns {event.EventEmitter}
	 */
	this.POST = function(path, options) {
		var extra = optional(options, {})
		var params = optional(extra.params, {})
		var headers = optional(extra.headers, {})
		var new_headers = merge({
			'content-type': 'application/x-www-form-urlencoded',
		}, headers)

		return authorized_call('POST', path, params, new_headers)
	}

	/**
	 * Perform a PUT request.
	 *
	 * Events
	 * done (response) - The decoded JSON object will be stored in response
	 * error (error) - The error will be stored in error
	 *
	 * @param {string} path - The path of the API call
	 * @param {object} [options={}] - Additional call options
	 * @param {object} [options.params={}] - Request parameters
	 * @param {object} [options.headers={}] - Additional request headers
	 * @returns {event.EventEmitter}
	 */
	this.PUT = function(path, options) {
		var extra = optional(options, {})
		var params = optional(extra.params, {})
		var headers = optional(extra.headers, {})
		var new_headers = merge({
			'content-type': 'application/x-www-form-urlencoded',
		}, headers)

		return authorized_call('PUT', path, params, new_headers)
	}

	/**
	 * Perform a DELETE request.
	 *
	 * Events
	 * done (response) - The decoded JSON object will be stored in response
	 * error (error) - The error will be stored in error
	 *
	 * @param {string} path - The path of the API call
	 * @param {object} [options={}] - Additional call options
	 * @param {object} [options.params={}] - Request parameters
	 * @param {object} [options.headers={}] - Additional request headers
	 * @returns {event.EventEmitter}
	 */
	this.DELETE = function(path, options) {
		var extra = optional(options, {})
		var params = optional(extra.params, {})
		var headers = optional(extra.headers, {})

		var query = querystring.stringify(params)
		var new_path = path
		if (query) {
			new_path += '?' + query
		}

		return authorized_call('DELETE', new_path, {}, headers)
	}

	/**
	 * @returns {string} Current access token
	 */
	this.getToken = function() {
		return _token
	}

	return __construct(this)
}

module.exports.Connection = Connection
