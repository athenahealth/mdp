//    Copyright 2014 athenahealth, Inc.
//
//   Licensed under the Apache License, Version 2.0 (the "License"); you
//   may not use this file except in compliance with the License.  You
//   may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
//   implied.  See the License for the specific language governing
//   permissions and limitations under the License.
																		
using System;
using System.Collections.Generic;
using System.Json;
using System.Linq;
using System.Threading;
using Athenahealth;

public class Testing
{
  static public void Main()
  {
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Setup
	////////////////////////////////////////////////////////////////////////////////////////////////
	string key = "CHANGEME: YOUR_API_KEY";
	string secret = "CHANGEME: YOUR_API_SECRET";
	string version = "preview1";
	string practiceid = "000000";
		
	APIConnection api = new APIConnection(version, key, secret, practiceid);
		
	// If you want to set the practice ID after construction, this is how.
	// api.PracticeID = "000000";


	////////////////////////////////////////////////////////////////////////////////////////////////
	// GET without parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	JsonValue customfields = api.GET("/customfields");
	Console.WriteLine("Custom fields:");
	foreach (JsonValue field in customfields)
	  {
		Console.WriteLine("\t" + field["name"]);
	  }

	////////////////////////////////////////////////////////////////////////////////////////////////
	// GET with parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	string format = "MM/dd/yyyy";
	DateTime today = DateTime.Now;
	DateTime nextyear = today.AddYears(1);
	
	Dictionary<string, string> search = new Dictionary<string, string>()
	  {
		{"departmentid", "82"},
		{"startdate", today.ToString(format)},
		{"enddate", nextyear.ToString(format)},
		{"appointmenttypeid", "2"},
		{"limit", "1"},
	  };
	
	JsonValue open_appts = api.GET("/appointments/open", search);
	Console.WriteLine(open_appts.ToString());
	JsonValue appt = open_appts["appointments"][0];
	Console.WriteLine("Open appointment:");
	Console.WriteLine(appt.ToString());
		
	Dictionary<string, string> newAppt = new Dictionary<string, string>();
	foreach (KeyValuePair<string, JsonValue> kvp in appt)
	  {
		newAppt[kvp.Key] = kvp.Value.ToString();
	  }
	

	// add keys to make appt usable for scheduling
	appt["appointmenttime"] = appt["starttime"];
	appt["appointmentdate"] = appt["date"];


	// Thread.Sleep(1000); 		// NOTE: Uncomment this line if you keep getting "Over QPS" errors
	////////////////////////////////////////////////////////////////////////////////////////////////
	// POST with parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	Dictionary<string, string> patientInfo = new Dictionary<string, string>()
	  {
		{"departmentid", "1"},
		{"lastname", "Foo"},
		{"firstname", "Jason"},
		{"address1", "123 Any Street"},
		{"city", "Cambridge"},
		{"countrycode3166", "US"},
		{"dob", "6/18/1987"},
		{"language6392code", "declined"},
		{"maritalstatus", "S"},
		{"race", "declined"},
		{"sex", "M"},
		{"ssn", "*****1234"},
		{"zip", "02139"},
	  };

	JsonValue newPatient = api.POST("/patients", patientInfo);
	Console.WriteLine(newPatient.ToString());
	string newPatientID = newPatient[0]["patientid"];
	Console.WriteLine("New patient id:");
	Console.WriteLine(newPatientID);
		

	////////////////////////////////////////////////////////////////////////////////////////////////
	// PUT with parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	Dictionary<string, string> appointmentInfo = new Dictionary<string, string>()
	  {
		{"appointmenttypeid", "82"},
		{"departmentid", "1"},
		{"patientid", newPatientID},
	  };
		
	JsonValue booked = api.PUT("/appointments/" + appt["appointmentid"], appointmentInfo);
	Console.WriteLine("Booked:");
	Console.WriteLine(booked.ToString());
		
	
	// Thread.Sleep(1000); 		// NOTE: Uncomment this line if you keep getting "Over QPS" errors
	////////////////////////////////////////////////////////////////////////////////////////////////
	// POST without parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	JsonValue checked_in = api.POST(string.Format("/appointments/{0}/checkin", appt["appointmentid"]));
	Console.WriteLine("Check-in:");
	Console.WriteLine(checked_in.ToString());
		
		
	////////////////////////////////////////////////////////////////////////////////////////////////
	// DELETE with parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	Dictionary<string, string> deleteParams = new Dictionary<string, string>()
	  {
		{"departmentid", "1"},
	  };
	JsonValue chartAlert = api.DELETE(string.Format("/patients/{0}/chartalert", newPatientID), deleteParams);
	Console.WriteLine("Removed chart alert:");
	Console.WriteLine(chartAlert.ToString());
		
		
	////////////////////////////////////////////////////////////////////////////////////////////////
	// DELETE without parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	JsonValue photo = api.DELETE(string.Format("/patients/{0}/photo", newPatientID));
	Console.WriteLine("Removed photo:");
	Console.WriteLine(photo.ToString());
		
		
	////////////////////////////////////////////////////////////////////////////////////////////////
	// There are no PUTs without parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
		
		
	// Thread.Sleep(1000); 		// NOTE: Uncomment this line if you keep getting "Over QPS" errors
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Error conditions
	////////////////////////////////////////////////////////////////////////////////////////////////
	JsonValue badPath = api.GET("/nothing/at/this/path");
	Console.WriteLine("GET /nothing/at/this/path:");
	Console.WriteLine(badPath.ToString());
	JsonValue missingParameters = api.GET("/appointments/open");
	Console.WriteLine("Missing parameters:");
	Console.WriteLine(missingParameters.ToString());


	////////////////////////////////////////////////////////////////////////////////////////////////
	// Testing token refresh
	//
	// NOTE: this test takes an hour, so it's disabled by default. Change false to true to run.
	////////////////////////////////////////////////////////////////////////////////////////////////
	if (false) {
	  string oldToken = api.GetToken();
	  Console.WriteLine("Old token: " + oldToken);
			
	  api.GET("/departments");
			
	  // Wait 3600 seconds = 1 hour for token to expire.
	  Thread.Sleep(3600 * 1000);
			
	  api.GET("/departments");
			
	  Console.WriteLine("New token: " + api.GetToken());
	}
  }
}

