#!/usr/bin/env nodejs

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

var key = 'CHANGEME: YOUR_API_KEY'
var secret = 'CHANGEME: YOUR_API_SECRET'
var version = 'preview1'
var practiceid = 000000

var auth_prefixes = {
	v1: '/oauth',
	preview1: '/oauthpreview',
	openpreview1: '/oauthopenpreview',
}

// This is a useful function to have
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

// Since we want these functions to run in a set order, we need a way to signal for the next one.
var signal = new events.EventEmitter

// We need to save the token in an outer scope, because of callbacks.
var token

function authentication() {
	var req = https.request({
		// Set up the request, making sure the content-type header is set. Let the https library do
		// the auth header (including base64 encoding) for us.
		hostname: 'api.athenahealth.com',
		method: 'POST',
		path: path_join(auth_prefixes[version], '/token'),
		auth: key + ':' + secret,
		headers: {'content-type': 'application/x-www-form-urlencoded'},
	}, function(response) {
		response.setEncoding('utf8')
		var content = ''
		response.on('data', function(chunk) {
			content += chunk
		})
		response.on('end', function() {
			var authorization = JSON.parse(content)
			// Save the token!
			token = authorization.access_token
			console.log(token)
			signal.emit('next')
		})
	})

	req.on('error', function(e) {
		console.log(e.message)
	})

	// The one parameter required for OAuth
	req.write(querystring.stringify({grant_type: 'client_credentials'}))
	req.end()
}

function departments() {
	// Create and encode parameters
	var parameters = {
		limit: 1,
	}
	var query = '?' + querystring.stringify(parameters)

	var req = https.request({
		hostname: 'api.athenahealth.com',
		method: 'GET',
		path: path_join(version, practiceid, '/departments', query),
		// We set the auth header ourselves this time, because we have a token now.
		headers: {'authorization': 'Bearer ' + token},
	}, function(response) {
		response.setEncoding('utf8')
		var content = ''
		response.on('data', function(chunk) {
			content += chunk
		})
		response.on('end', function() {
			console.log('Department:')
			console.log(JSON.parse(content))
			signal.emit('next')
		})
	})
	req.on('error', function(e) {
		console.log(e.message)
	})

	req.end()
}

function notes() {
	var parameters = {
		notetext: 'Javascript says hi!',
	}
	var content = querystring.stringify(parameters)
	var req = https.request({
		hostname: 'api.athenahealth.com',
		method: 'POST',
		path: path_join(version, practiceid, '/appointments/1/notes'),
		headers: {
			'authorization': 'Bearer ' + token,
			'content-type': 'application/x-www-form-urlencoded',
			'content-length': content.length, // apparently we have to set this ourselves when using
											  // application/x-www-form-urlencoded
		},
	}, function(response) {
		response.setEncoding('utf8')
		var content = ''
		response.on('data', function(chunk) {
			content += chunk
		})
		response.on('end', function() {
			console.log('Note posted:')
			console.log(JSON.parse(content))
			signal.emit('next')
		})
	})
	req.on('error', function(e) {
		console.log(e.message)
	})

	req.write(content)
	req.end()
}

// This is one way of forcing the call order
function main() {
	var calls = [authentication, departments, notes]
	signal.on('next', function() {
		var nextCall = calls.shift()
		if (nextCall) {
			nextCall()
		}
	})
	signal.emit('next')
}

main()
