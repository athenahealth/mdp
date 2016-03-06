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
require 'json'
require './apiconnection.rb'

class Authenticator
  attr_reader :key, :secret, :token

  def initialize
    unless load_saved_token
      request_token
    end
  end

  def version
    'preview1'
  end

  def load_key_and_secret
    @key = File.read('.key').chomp
    @secret = File.read('.secret').chomp

    unless @key && @secret
      raise "Must have a '.key' and '.secret' file to authenticate"
    end
  end

  def request_token connection=ApiConnection.new

    # Authenticate (basic access authentication)
    auth_paths = {
      'v1' => 'oauth',
      'preview1' => 'oauthpreview',
      'openpreview1' => 'oauthopenpreview',
    }

    load_key_and_secret

    request = Net::HTTP::Post.new("/#{auth_paths[version]}/token")
   
    request.basic_auth @key, @secret
    request.set_form_data({'grant_type' => 'client_credentials'})

    response = connection.request(request)
    authorization = JSON.parse(response.body)

    # Save the token for later
    @token = authorization['access_token']

    if @token
      puts "Token received successfully!"
      save_token!
    else
      raise "Did not receive a token"
    end
  end

  def save_token!
    File.open('.token', 'w') do |f|
      f.puts @token
    end
  end

  def load_saved_token
    @token = nil
    if File.file? '.token'
      @token = File.read('.token').chomp
    end
    @token
  end

  def set_token request
    raise "No token to set, please load or generate one" unless @token

    request['authorization'] = "Bearer #{@token}"
    request
  end
end
