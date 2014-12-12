#!/usr/bin/env php
<?php
/*
   Copyright 2014 athenahealth, Inc.

   Licensed under the Apache License, Version 2.0 (the "License"); you
   may not use this file except in compliance with the License.  You
   may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
   implied.  See the License for the specific language governing
   permissions and limitations under the License. 
*/

require dirname(__FILE__) . '/athenahealthapi.php';

####################################################################################################
# Setup
####################################################################################################
$key = 'CHANGEME: YOUR_API_KEY';
$secret = 'CHANGEME: YOUR_API_SECRET';
$version = 'preview1';
$practiceid = 000000;

$api = new APIConnection($version, $key, $secret, $practiceid);

# If you want to change the practiceid after initialization, this is how.
# $api->practiceid = 000000;


####################################################################################################
# GET without parameters
####################################################################################################
$customfields = $api->GET('/customfields');
echo "Custom fields:\n";
print_r($customfields[0]);


####################################################################################################
# GET with parameters
####################################################################################################
date_default_timezone_set('America/New_York');
$dateformat = 'm/d/Y';
$today = date($dateformat);
$nextyear = date($dateformat, strtotime('+1 year'));

$open_appts = $api->GET('/appointments/open', array(
	'departmentid' => 82,
	'startdate' => $today, 
	'enddate' => $nextyear, 
	'appointmenttypeid' => 2,
	'limit' => 1,
));
$appt = $open_appts['appointments'][0];
echo "Open appointment:\n";
print_r($appt);

# change the keys it appt to make it usable in scheduling
$appt['appointmenttime'] = $appt['starttime'];
$appt['appointmentdate'] = $appt['date'];
unset($appt['starttime']);
unset($appt['date']);


####################################################################################################
# POST with parameters
####################################################################################################
$patient_info = array(
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
);

$new_patient = $api->POST('/patients', $patient_info);

$new_patient_id = $new_patient[0]['patientid'];
echo "New patient id: $new_patient_id\n";


####################################################################################################
# PUT with parameters
####################################################################################################
$appointment_info = array(
	'appointmenttypeid' => 82,
	'departmentid' => 1,
	'patientid' => $new_patient_id,
);

$booked = $api->PUT('/appointments/' . $appt['appointmentid'], $appointment_info);
echo "Response to booking appointment:\n";
print_r($booked);


####################################################################################################
# POST without parameters
####################################################################################################
$checked_in = $api->POST('/appointments/' . $appt['appointmentid'] . '/checkin');
echo "Response to check-in:\n";
print_r($checked_in);


####################################################################################################
# DELETE with parameters
####################################################################################################
$removed_chart_alert = $api->DELETE('/patients/' . $new_patient_id . 'chartalert', array('departmentid' => 1));
echo "Removed chart alert:\n";
print_r($removed_chart_alert);


####################################################################################################
# DELETE without parameters
####################################################################################################
$removed_appointment = $api->DELETE('/appointments/' . $appt['appointmentid']);
echo "Removed appointment:\n";
print_r($removed_appointment);

####################################################################################################
# There are no PUTs without parameters
####################################################################################################



####################################################################################################
# Error conditions
####################################################################################################
$bad_path = $api->GET('/nothing/at/this/path');
echo "GET /nothing/at/this/path:\n";
print_r($bad_path);

$missing_parameters = $api->GET('/appointments/open');
echo "Response to missing parameters:\n";
print_r($missing_parameters);


####################################################################################################
# Testing refresh tokens
####################################################################################################

# NOTE: This test takes an hour to run, so it's disabled by default. Change false to true to run it.
if (false) {
	$oldtoken = $api->get_token();
	echo 'Old token: ' . $oldtoken . "\n";
	
	$before_refresh = $api->GET('/departments');
	
	# Wait 3600 seconds = 1 hour for token to expire.
	sleep(3600);
	
	$after_refresh = $api->GET('/departments');
	
	echo 'New token: ' . $api->get_token() . "\n";
}

?>