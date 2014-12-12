/*
 *    Copyright 2014 athenahealth, Inc.
 *
 *   Licensed under the Apache License, Version 2.0 (the "License"); you
 *   may not use this file except in compliance with the License.  You
 *   may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *   Unless required by applicable law or agreed to in writing, software
 *   distributed under the License is distributed on an "AS IS" BASIS,
 *   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 *   implied.  See the License for the specific language governing
 *   permissions and limitations under the License.
 */
																		
package test;

import com.athenahealth.api.APIConnection;
import org.json.JSONObject;
import org.json.JSONArray;
import java.util.Calendar;
import java.util.Map;
import java.util.HashMap;
import java.text.SimpleDateFormat;

class Testing {
	public static void main(String[] args) throws Exception {
		////////////////////////////////////////////////////////////////////////////////////////////
		// Setup
		////////////////////////////////////////////////////////////////////////////////////////////
		String key = "CHANGEME: YOUR_API_KEY";
		String secret = "CHANGEME: YOUR_API_SECRET";
		String version = "preview1";
		String practiceid = "000000";
		
		APIConnection api = new APIConnection(version, key, secret, practiceid);
		
		// If you want to set the practice ID after construction, this is how.
		// api.setPracticeID("000000");
		
		
		////////////////////////////////////////////////////////////////////////////////////////////
		// GET without parameters
		////////////////////////////////////////////////////////////////////////////////////////////
		JSONArray customfields = (JSONArray) api.GET("/customfields");
		System.out.println("Custom fields:");
		for (int i = 0; i < customfields.length(); i++) {
			System.out.println("\t" + customfields.getJSONObject(i).get("name"));
		}
		
		
		////////////////////////////////////////////////////////////////////////////////////////////
		// GET with parameters
		////////////////////////////////////////////////////////////////////////////////////////////
		SimpleDateFormat format = new SimpleDateFormat("MM/dd/yyyy");
		Calendar today = Calendar.getInstance();
		Calendar nextyear = Calendar.getInstance();
		nextyear.roll(Calendar.YEAR, 1);
		
		Map<String, String> search = new HashMap<String, String>();
		search.put("departmentid", "82");
		search.put("startdate", format.format(today.getTime()));
		search.put("enddate", format.format(nextyear.getTime()));
		search.put("appointmenttypeid", "2");
		search.put("limit", "1");
		
	    JSONObject open_appts = (JSONObject) api.GET("/appointments/open", search);
		System.out.println(open_appts.toString());
		JSONObject appt = open_appts.getJSONArray("appointments").getJSONObject(0);
		System.out.println("Open appointment:");
		System.out.println(appt.toString());
		
		// add keys to make appt usable for scheduling
		appt.put("appointmenttime", appt.get("starttime"));
		appt.put("appointmentdate", appt.get("date"));
		
		
		////////////////////////////////////////////////////////////////////////////////////////////
		// POST with parameters
		////////////////////////////////////////////////////////////////////////////////////////////
		Map<String, String> patient_info = new HashMap<String, String>();
		patient_info.put("lastname", "Foo");
		patient_info.put("firstname", "Jason");
		patient_info.put("address1", "123 Any Street");
		patient_info.put("city", "Cambridge");
		patient_info.put("countrycode3166", "US");
		patient_info.put("departmentid", "1");
		patient_info.put("dob", "6/18/1987");
		patient_info.put("language6392code", "declined");
		patient_info.put("maritalstatus", "S");
		patient_info.put("race", "declined");
		patient_info.put("sex", "M");
		patient_info.put("ssn", "*****1234");
		patient_info.put("zip", "02139");
		
		JSONArray new_patient = (JSONArray) api.POST("/patients", patient_info);
		String new_patient_id = new_patient.getJSONObject(0).getString("patientid");
		System.out.println("New patient id:");
		System.out.println(new_patient_id);
		

		////////////////////////////////////////////////////////////////////////////////////////////
		// PUT with parameters
		////////////////////////////////////////////////////////////////////////////////////////////
		Map<String, String> appointment_info = new HashMap<String, String>();
		appointment_info.put("appointmenttypeid", "82");
		appointment_info.put("departmentid", "1");
		appointment_info.put("patientid", new_patient_id);
		
		JSONArray booked = (JSONArray) api.PUT("/appointments/" + appt.getString("appointmentid"), appointment_info);
		System.out.println("Booked:");
		System.out.println(booked.toString());
		
	
		
		////////////////////////////////////////////////////////////////////////////////////////////
		// POST without parameters
		////////////////////////////////////////////////////////////////////////////////////////////
		JSONObject checked_in = (JSONObject) api.POST("/appointments/" + appt.getString("appointmentid") + "/checkin");
		System.out.println("Check-in:");
		System.out.println(checked_in.toString());
		
		
		////////////////////////////////////////////////////////////////////////////////////////////
		// DELETE with parameters
		////////////////////////////////////////////////////////////////////////////////////////////
		Map<String, String> delete_params = new HashMap<String, String>();
		delete_params.put("departmentid", "1");
		JSONObject chart_alert = (JSONObject) api.DELETE("/patients/" + new_patient_id + "/chartalert", delete_params);
		System.out.println("Removed chart alert:");
		System.out.println(chart_alert.toString());
		
		
		////////////////////////////////////////////////////////////////////////////////////////////
		// DELETE without parameters
		////////////////////////////////////////////////////////////////////////////////////////////
		JSONObject photo = (JSONObject) api.DELETE("/patients/" + new_patient_id + "/photo");
		System.out.println("Removed photo:");
		System.out.println(photo.toString());
		
		
		////////////////////////////////////////////////////////////////////////////////////////////
		// There are no PUTs without parameters
		////////////////////////////////////////////////////////////////////////////////////////////
		
		
		////////////////////////////////////////////////////////////////////////////////////////////
		// Error conditions
		////////////////////////////////////////////////////////////////////////////////////////////
		JSONObject bad_path = (JSONObject) api.GET("/nothing/at/this/path");
		System.out.println("GET /nothing/at/this/path:");
		System.out.println(bad_path.toString());
		JSONObject missing_parameters = (JSONObject) api.GET("/appointments/open");
		System.out.println("Missing parameters:");
		System.out.println(missing_parameters.toString());
		
		
		////////////////////////////////////////////////////////////////////////////////////////////
		// Testing token refresh
		//
		// NOTE: this test takes an hour, so it's disabled by default. Change false to true to run.
		////////////////////////////////////////////////////////////////////////////////////////////
		if (false) {
			String old_token = api.getToken();
			System.out.println("Old token: " + old_token);
			
			JSONObject before_refresh = (JSONObject) api.GET("/departments");
			
			// Wait 3600 seconds = 1 hour for token to expire.
			try {
				Thread.sleep(3600 * 1000);
			}
			catch (InterruptedException e) {
				Thread.currentThread().interrupt();
			}
			
			JSONObject after_refresh = (JSONObject) api.GET("/departments");
			
			System.out.println("New token: " + api.getToken());
		}
	}
}
