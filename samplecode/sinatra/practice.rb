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

require './apirequest.rb'

class Practice
  attr_reader :id, :departments, :name

  def initialize id
    @id = id
    @departments = []
  end

  def self.base_path
    @base_path ||= "/#{$authenticator.version}/#{@id}"
  end

  def getDepartments
    dept_request = ApiRequest.new Department, { 'limit' => 1 } 

    @departments = dept_request.try_request
  end
end