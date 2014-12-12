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

require 'athenahealthapi'
require 'pp'
require 'date'

####################################################################################################
# Setup
####################################################################################################
version = 'preview1'
key = 'CHANGEME: YOUR_API_KEY'
secret = 'CHANGEME: YOUR_API_SECRET'
practiceid = 000000             # CHANGEME: your practiceid

api = AthenahealthAPI::Connection.new(version, key, secret, practiceid)

# If you want to change which practice you're working with after initialization, this is how.
# api.practiceid = 000000


####################################################################################################
# GET without parameters
####################################################################################################
customfields = api.GET('/customfields')
puts 'Custom fields:'
pp customfields[0].keys()


####################################################################################################
# GET with parameters
####################################################################################################
dateformat = '%m/%d/%Y'
today = DateTime.now
nextyear = today >> 12          # "shift forward" 12 months

appt_params = {
  'departmentid' => 82,
  'startdate' => today.strftime(dateformat), 
  'enddate' => nextyear.strftime(dateformat), 
  'appointmenttypeid' => 2,
  'limit' => 1,
}
open_appts = api.GET('/appointments/open', appt_params)
appt = open_appts['appointments'][0]
puts 'Open appointment:'
pp appt

# change the keys in appt to make it usable in scheduling
appt['appointmenttime'] = appt['starttime']
appt['appointmentdate'] = appt['date']
appt.delete('starttime')
appt.delete('date')


####################################################################################################
# POST with parameters
####################################################################################################
patient_info = {
  'lastname' => 'Foo',
  'firstname' => 'Jason',
  'address1' => '123 Any Street',
  'city' => 'Cambridge',
  'countrycode3166' => 'US',
  'departmentid' => 1,
  'dob' => '6/18/1987',
  'language6392code' => 'declined',
  'maritalstatus' => 'S',
  'race' => 'declined',
  'sex' => 'M',
  'ssn' => '*****1234',
  'zip' => '02139',
}

new_patient = api.POST('/patients', patient_info)    

pp new_patient
new_patient_id = new_patient[0]['patientid']
puts 'New patient id:'
pp new_patient_id


####################################################################################################
# PUT with parameters
####################################################################################################
appointment_info = {
  'appointmenttypeid' => 82,
  'departmentid' => 1,
  'patientid' => new_patient_id,
}

booked = api.PUT("/appointments/#{appt['appointmentid']}", appointment_info)
puts 'Response to booking appointment:'
pp booked


####################################################################################################
# POST without parameters
####################################################################################################
checked_in = api.POST("/appointments/#{appt['appointmentid']}/checkin")
puts 'Response to check-in:'
pp checked_in


####################################################################################################
# DELETE with parameters
####################################################################################################
removed_chart_alert = api.DELETE("/patients/#{new_patient_id}/chartalert", {'departmentid' => 1})
puts 'Removed chart alert:'
pp removed_chart_alert


####################################################################################################
# DELETE without parameters
####################################################################################################
removed_appointment = api.DELETE("/appointments/#{appt['appointmentid']}")
puts 'Removed appointment:'
pp removed_appointment

####################################################################################################
# There are no PUTs without parameters
####################################################################################################


####################################################################################################
# Error conditions
####################################################################################################
bad_path = api.GET('/nothing/at/this/path')
puts 'GET /nothing/at/this/path:'
pp bad_path

missing_parameters = api.GET('/appointments/open')  
puts 'Response to missing parameters:'
pp missing_parameters


####################################################################################################
# Testing refresh tokens
####################################################################################################

# NOTE: This test takes an hour to run, so it's disabled by default. Change false to true to run it.
if false
  oldtoken = api.token
  puts "Old token: #{oldtoken}"
  
  before_refresh = api.GET('/departments')
  
  
  # Wait 3600 seconds = 1 hour for token to expire.  If you don't need (or want) the progress
  # tracking, use the following line instead of the for-else block: 
  sleep(3600)
  
  after_refresh = api.GET('/departments')
  
  puts "New token: #{api.token}"
end
