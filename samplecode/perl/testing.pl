#!/usr/bin/env perl

#   Copyright 2014 athenahealth, Inc.
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

use strict;
use warnings;

use athenahealthapi;
use Data::Dumper;
use Time::localtime;


####################################################################################################
# Setup
####################################################################################################
my ($key, $secret) = ('CHANGEME: YOUR_API_KEY', 'CHANGEME: YOUR_API_SECRET');
my $version = 'preview1';
my $practiceid = 000000;

my $api = athenahealthapi->new($version, $key, $secret, $practiceid);

# If you want to change which practice you're working with after initialization, this is how.
# $api->{practiceid} = 000000;


####################################################################################################
# GET without parameters
####################################################################################################
my $customfields = $api->GET({path => '/customfields'});
my @customfieldnames = map { '"' . $_->{name} . '"' } @$customfields;
print 'Custom fields: ' . join(', ', @customfieldnames) . "\n";
	

####################################################################################################
# GET with parameters
####################################################################################################
my $tm = localtime;
my ($day, $month, $year) = ($tm->mday, $tm->mon + 1, $tm->year + 1900);
my $nextyear = $year + 1;
my $today = "$month/$day/$year";
my $future = "$month/$day/$nextyear";

my $open_appts = $api->GET({
	path => '/appointments/open', 
	params => {
		departmentid => 82,
		startdate => $today,
		enddate => $future, 
		appointmenttypeid => 2,
		limit => 1,
	},
});
my $appt = $open_appts->{appointments}[0];
print 'Open appointment:' . "\n";
print Dumper $appt;

# change the keys in appt to make it usable in scheduling
$appt->{appointmenttime} = delete $appt->{starttime};
$appt->{appointmentdate} = delete $appt->{date};


####################################################################################################
# POST with parameters
####################################################################################################
my $patient_info = {
	lastname => 'Foo',
	firstname => 'Jason',
	address1 => '123 Any Street',
	city => 'Cambridge',
	countrycode3166 => 'US',
	departmentid => 1,
	dob => '6/18/1987',
	language6392code => 'declined',
	maritalstatus => 'S',
	race => 'declined',
	sex => 'M',
	ssn => '*****1234',
	zip => '02139',
};

my $new_patient = $api->POST({
	path => '/patients', 
	params => $patient_info,
});

my $new_patient_id = $new_patient->[0]->{patientid};
print 'New patient id: '. $new_patient_id . "\n";


####################################################################################################
# PUT with parameters
####################################################################################################
my $appointment_info = {
	appointmenttypeid => 82,
	departmentid => 1,
	patientid => $new_patient_id,
};

my $booked = $api->PUT({
	path => '/appointments/' . $appt->{appointmentid}, 
	params => $appointment_info,
});

print 'Response to booking appointment:' . "\n";
print Dumper $booked;


####################################################################################################
# POST without parameters
####################################################################################################
my $checked_in = $api->POST({
	path => '/appointments/' . $appt->{appointmentid} . '/checkin',
});
print 'Response to check-in:' . "\n";
print Dumper $checked_in;


####################################################################################################
# DELETE with parameters
####################################################################################################
my $removed_chart_alert = $api->DELETE({
	path => '/patients/' . $new_patient_id . 'chartalert',
	params => {
		departmentid => 1,
	},
});
print 'Removed chart alert:' . "\n";
print Dumper $removed_chart_alert;


####################################################################################################
# DELETE without parameters
####################################################################################################
my $removed_appointment = $api->DELETE({
	path => '/appointments/' . $appt->{appointmentid},
});
print 'Removed appointment:' . "\n";
print Dumper $removed_appointment;

####################################################################################################
# There are no PUTs without parameters
####################################################################################################


####################################################################################################
# Error conditions
####################################################################################################
my $bad_path = $api->GET({path => '/nothing/at/this/path'});
print 'GET /nothing/at/this/path:' . "\n";
print Dumper $bad_path->{error};
my $missing_parameters = $api->GET({path => '/appointments/open'});
print 'Response to missing parameters:' . "\n";
print Dumper $missing_parameters;


####################################################################################################
# Testing refresh tokens
####################################################################################################

# NOTE: This test takes an hour to run, so it's disabled by default. Change 0 to 1 to run it.
if (0) {
    my $oldtoken = $api->get_token();
    print 'Old token: ' . $oldtoken . "\n";
    
    my $before_refresh = $api->GET({path => '/departments'});
    
    # Wait 3600 seconds = 1 hour for token to expire.
    sleep(3600);
        
    my $after_refresh = $api->GET({path => '/departments'});
	print 'New token: ' . $api->get_token() . "\n";
}
