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
This file shows examples of how to use the athenahealthapi module to perform More Disruption Please
API calls.  The APIConnection object handles the tedious parts of the calls, such as authentication
tokens and headers, so code can be clearer.
"""

import athenahealthapi
import datetime

####################################################################################################
# Setup
####################################################################################################
key = 'CHANGEME: YOUR_API_KEY'
secret = 'CHANGEME: YOUR_API_SECRET'
environment = 'preview'
version = 'v1'
practiceid = 000000

api = athenahealthapi.APIConnection(environment, version, key, secret, practiceid)

# If you want to change which practice you're working with after initialization, this is how.
# api.practiceid = 000000

# Before we start, here's a useful function.
def path_join(*args):
    return ''.join('/' + str(arg).strip('/') for arg in args if arg)  


####################################################################################################
# GET without parameters
####################################################################################################
customfields = api.GET('/customfields')
print('Custom fields:', list(customfields[0].keys()))


####################################################################################################
# GET with parameters
####################################################################################################
today = datetime.date.today()
nextyear = today.replace(year = today.year + 1)
dateformat = '%m/%d/%Y'

open_appts = api.GET('/appointments/open', {
    'departmentid': 82,
    'startdate': today.strftime(dateformat), 
    'enddate': nextyear.strftime(dateformat), 
    'appointmenttypeid': 2,
    'limit': 1,
})
appt = open_appts['appointments'][0]
print('Open appointment:', appt)

# change the keys in appt to make it usable in scheduling
appt['appointmenttime'] = appt.pop('starttime')
appt['appointmentdate'] = appt.pop('date')


####################################################################################################
# POST with parameters
####################################################################################################
patient_info = {
    'lastname': 'Foo',
    'firstname': 'Jason',
    'address1': '123 Any Street',
    'city': 'Cambridge',
    'countrycode3166': 'US',
    'departmentid': 1,
    'dob': '6/18/1987',
    'language6392code': 'declined',
    'maritalstatus': 'S',
    'race': 'declined',
    'sex': 'M',
    'ssn': '*****1234',
    'zip': '02139',
}

new_patient = api.POST('/patients', patient_info)    

new_patient_id = new_patient[0]['patientid']
print('New patient id:', new_patient_id)


####################################################################################################
# PUT with parameters
####################################################################################################
appointment_info = {
    'appointmenttypeid': 82,
    'departmentid': 1,
    'patientid': new_patient_id,
}

booked = api.PUT(path_join('/appointments', appt['appointmentid']), appointment_info)
print('Response to booking appointment:', booked)


####################################################################################################
# POST without parameters
####################################################################################################
checked_in = api.POST(path_join('/appointments', appt['appointmentid'], '/checkin'))
print('Response to check-in:', checked_in)


####################################################################################################
# DELETE with parameters
####################################################################################################
removed_chart_alert = api.DELETE(path_join('/patients', new_patient_id, 'chartalert'), {'departmentid': 1})
print('Removed chart alert:', removed_chart_alert)


####################################################################################################
# DELETE without parameters
####################################################################################################
removed_appointment = api.DELETE(path_join('/appointments', appt['appointmentid']))
print('Removed appointment:', removed_appointment)

####################################################################################################
# There are no PUTs without parameters
####################################################################################################


####################################################################################################
# Error conditions
####################################################################################################
bad_path = api.GET('/nothing/at/this/path')
print('GET /nothing/at/this/path:', bad_path['error'])
missing_parameters = api.GET('/appointments/open')  
print('Response to missing parameters:', missing_parameters['error'], missing_parameters['missingfields'])


####################################################################################################
# Testing refresh tokens
####################################################################################################

# NOTE: This test takes an hour to run, so it's disabled by default. Change False to True to run it.
if False:
    import time
    import sys
    
    oldtoken = api.get_token()
    print('Old token:', oldtoken)
    
    before_refresh = api.GET('/departments')
    
    # Wait 3600 seconds = 1 hour for token to expire.
    time.sleep(3600)
       
    after_refresh = api.GET('/departments')
    
    print('New token:', api.get_token())
