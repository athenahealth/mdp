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
																		
import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.Iterator;
import java.util.HashMap;
import java.util.Map;
import org.apache.commons.codec.binary.Base64;
import org.json.JSONArray;
import org.json.JSONObject;

class Naive {
	public static void main(String[] args) throws Exception {
		// Basic access authentication setup
		String key = "CHANGEME: YOUR_API_KEY";
		String secret = "CHANGEME: YOUR_API_SECRET";
		String version = "preview1"; // CHANGEME: the API version to use
		String practiceid = "000000"; // CHANGEME: the practice ID to use
		
		
		// Find the authentication path
		Map<String, String> auth_prefix = new HashMap<String, String>();
		auth_prefix.put("v1", "oauth");
		auth_prefix.put("preview1", "oauthpreview");
		auth_prefix.put("openpreview1", "oauthopenpreview");
		
		URL authurl = new URL("https://api.athenahealth.com/" + auth_prefix.get(version) + "/token");
		
		HttpURLConnection conn = (HttpURLConnection) authurl.openConnection();
		conn.setRequestMethod("POST");
		
		// Set the Authorization request header
		String auth = Base64.encodeBase64String((key + ':' + secret).getBytes());
		conn.setRequestProperty("Authorization", "Basic " + auth);
		
		// Since this is a POST, the parameters go in the body
		conn.setDoOutput(true);
		String contents = "grant_type=client_credentials";
		DataOutputStream wr = new DataOutputStream(conn.getOutputStream());
		wr.writeBytes(contents);
		wr.flush();
		wr.close();

		// Read the response
		BufferedReader rd = new BufferedReader(new InputStreamReader(conn.getInputStream()));
		StringBuilder sb = new StringBuilder();
		String line;
		while((line = rd.readLine()) != null) {
			sb.append(line);
		}
		rd.close();
		
		// Decode from JSON and save the token for later
		String response = sb.toString();
		JSONObject authorization = new JSONObject(response);
		String token = authorization.get("access_token").toString();
		
		
		// GET /departments
		HashMap<String, String> params = new HashMap<String, String>();
		params.put("limit", "1");
		
		// Set up the URL, method, and Authorization header
		URL url = new URL("https://api.athenahealth.com/" + version + "/" + practiceid + "/departments" + "?" + urlencode(params));
		conn = (HttpURLConnection) url.openConnection();
		conn.setRequestMethod("GET");
		conn.setRequestProperty("Authorization", "Bearer " + token);
		
		rd = new BufferedReader(new InputStreamReader(conn.getInputStream()));
		sb = new StringBuilder();
		while((line = rd.readLine()) != null) {
			sb.append(line);
		}
		rd.close();
		
		response = sb.toString();
		JSONObject departments = new JSONObject(response);
		System.out.println(departments.toString());
		
		
		// POST /appointments/{appointmentid}/notes
		params = new HashMap<String, String>();
		params.put("notetext", "Hello from Java!");
		
		url = new URL("https://api.athenahealth.com/" + version + "/" + practiceid + "/appointments/1/notes");
		conn = (HttpURLConnection) url.openConnection();
		conn.setRequestMethod("POST");
		conn.setRequestProperty("Authorization", "Bearer " + token);

		// POST parameters go in the body
		conn.setDoOutput(true);
		contents = urlencode(params);
		wr = new DataOutputStream(conn.getOutputStream());
		wr.writeBytes(contents);
		wr.flush();
		wr.close();
		
		rd = new BufferedReader(new InputStreamReader(conn.getInputStream()));
		sb = new StringBuilder();
		while((line = rd.readLine()) != null) {
			sb.append(line);
		}
		rd.close();
		
		response = sb.toString();
		JSONObject note = new JSONObject(response);
		System.out.println(note.toString());
	}
	
	/**
	 * Converts request parameters into URL-safe form.
	 *
	 * @param parameters request parameters to encode
	 * @return           the URL-encoded parameters
	 */
	public static String urlencode(Map<?, ?> parameters) throws Exception {
		StringBuilder sb = new StringBuilder();
		boolean first = true;
		String encoding = "UTF-8";
		for (Map.Entry pair : parameters.entrySet()) {
			String k = pair.getKey().toString();
			String v = pair.getValue().toString();
			String current = URLEncoder.encode(k, encoding) + "=" + URLEncoder.encode(v, encoding);
			
			if (first) {
				first = false;
			}
			else {
				sb.append("&");
			}
			sb.append(current);
		}
		return sb.toString();
	}
}
