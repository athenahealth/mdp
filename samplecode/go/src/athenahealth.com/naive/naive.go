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

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"strings"
)

func main() {
	key := "CHANGEME: YOUR_API_KEY"
	secret := "CHANGEME: YOUR_API_SECRET"
	version := "preview1"
	practiceid := "000000"

	baseUrl := "https://api.athenahealth.com/"
	authPrefixes := map[string]string{
		"v1":           "/oauth",
		"preview1":     "/oauthpreview",
		"openpreview1": "/oauthopenpreview",
	}

	// client is used for all requests.
	client := &http.Client{}

	// Perform basic access authentication.  Make sure to make it a POST and to include grant_type
	// and Content-Type.
	authUrl := urlJoin(baseUrl, authPrefixes[version], "/token")
	parameters := url.Values{
		"grant_type": {"client_credentials"},
	}
	req, err := http.NewRequest("POST", authUrl, bytes.NewBufferString(parameters.Encode()))
	if err != nil {
		panic(err)
	}

	req.Header.Add("Content-Type", "application/x-www-form-urlencoded")
	req.SetBasicAuth(key, secret)

	// Send the request...
	resp, err := client.Do(req)
	if err != nil {
		panic(err)
	}
	// ... read the body of the response...
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		panic(err)
	}
	// ... (make sure to close the body when you're done)...
	defer resp.Body.Close()

	// ... decode/unmarshal the JSON...
	var decoded map[string]interface{}
	err = json.Unmarshal(body, &decoded)
	if err != nil {
		panic(err)
	}

	// ... and store the token.
	token := decoded["access_token"]
	fmt.Println(token)

	parameters = url.Values{
		"limit": {"1"},
	}
	reqUrl := urlJoin(baseUrl, version, practiceid, "/departments")

	// GET requests take parameters in the URL, and they have to be encoded properly.
	req, err = http.NewRequest("GET", reqUrl+"?"+parameters.Encode(), nil)
	if err != nil {
		panic(err)
	}

	// Make sure to include the Authorization header and token in future requests.
	req.Header.Add("Authorization", fmt.Sprintf("Bearer %s", token))

	resp, err = client.Do(req)
	if err != nil {
		panic(err)
	}
	body, err = ioutil.ReadAll(resp.Body)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	var departments map[string]interface{}
	err = json.Unmarshal(body, &departments)
	if err != nil {
		panic(err)
	}
	fmt.Println(departments)

	parameters = url.Values{
		"notetext": {"Hello from Go!"},
	}
	reqUrl = urlJoin(baseUrl, version, practiceid, "/appointments/1/notes")

	// POST requests take parameters in the body, so they need to be encoded and then converted to
	// bytes.
	req, err = http.NewRequest("POST", reqUrl, bytes.NewBufferString(parameters.Encode()))
	if err != nil {
		panic(err)
	}

	// POSTs also need the correct Content-Type.  And don't forget the access token!
	req.Header.Add("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Add("Authorization", fmt.Sprintf("Bearer %s", token))

	resp, err = client.Do(req)
	if err != nil {
		panic(err)
	}
	body, err = ioutil.ReadAll(resp.Body)
	defer resp.Body.Close()

	var note map[string]interface{}
	err = json.Unmarshal(body, &note)
	if err != nil {
		panic(err)
	}
	fmt.Println(note)
}

func urlJoin(args ...string) string {
	var trimmed []string
	for _, arg := range args {
		trimmed = append(trimmed, strings.Trim(arg, "/"))
	}
	return strings.Join(trimmed, "/")
}
