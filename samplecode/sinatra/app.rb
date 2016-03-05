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

require 'sinatra'
require './authenticator.rb'
require './department.rb'
require './provider.rb'

$practiceid = '195900'
$authenticator = Authenticator.new
$global_errors = ''

get '/' do
  erb :home
end

get '/departments' do
  @departments = Department.find limit: 5
  erb :departments
end

get '/providers' do
  @providers = Provider.find limit: 5
  erb :providers
end

after '*' do
  if $global_errors != ''
    @error = $global_errors
  end
end
