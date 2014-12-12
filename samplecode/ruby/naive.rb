#!/usr/bin/env ruby

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

require 'net/https'
require 'uri'
require 'cgi'
require 'rubygems'
require 'json'
require 'pp'

key = 'CHANGEME: YOUR_API_KEY'
secret = 'CHANGEME: YOUR_API_SECRET'
version = 'preview1'
practiceid = 000000


# Start a connection
uri = URI.parse('https://api.athenahealth.com/')
connection = Net::HTTP.new(uri.host, uri.port)
connection.use_ssl = true

# Monkey patch to make Net::HTTP do proper SSL verification.
# Background reading: 
# http://stackoverflow.com/a/9238221
# http://blog.spiderlabs.com/2013/06/a-friday-afternoon-troubleshooting-ruby-openssl-its-a-trap.html
def connection.proper_ssl_context!
  ssl_context = OpenSSL::SSL::SSLContext.new
  ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
  cert_store = OpenSSL::X509::Store.new
  cert_store.set_default_paths
  ssl_context.cert_store = cert_store
  @ssl_context = ssl_context
end
connection.proper_ssl_context!
# End monkey patch

# Authenticate (basic access authentication)
auth_paths = {
  'v1' => 'oauth',
  'preview1' => 'oauthpreview',
  'openpreview1' => 'oauthopenpreview',
}
request = Net::HTTP::Post.new("/#{auth_paths[version]}/token")
request.basic_auth(key, secret)
request.set_form_data({'grant_type' => 'client_credentials'})

response = connection.request(request)
authorization = JSON.parse(response.body)

# Save the token for later
token = authorization['access_token']
puts token


# This makes making paths easier
base_path = "/#{version}/#{practiceid}"


# GET /departments
params = {
  'limit' => 1,
}
query = params.map { |k,v| [k,v].map { |x| CGI.escape(x.to_s) }.join('=') }.join('&')
if query
  query = '?' + query
end

req2 = Net::HTTP::Get.new("#{base_path}/departments#{query}")
req2['authorization'] = "Bearer #{token}"

res2 = connection.request(req2)
departments = JSON.parse(res2.body)

puts 'Departments:'
pp departments


# POST /appointments/{appointmentid}/notes
appt_id = 1
req3 = Net::HTTP::Post.new("#{base_path}/appointments/#{appt_id}/notes")
req3.set_form_data({'notetext' => 'Notes from Ruby'})
req3['authorization'] = "Bearer #{token}"

res3 = connection.request(req3)
note = JSON.parse(res3.body)

puts 'Note:'
pp note
