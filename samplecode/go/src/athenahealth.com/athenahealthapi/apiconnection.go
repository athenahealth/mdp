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

// athenahealthapi abstracts away the HTTP connection and basic authentication from API calls.
package athenahealthapi

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"strings"
)

type Connection struct {
	key        string
	secret     string
	version    string
	practiceid string
	token      string
	basepath   string
	client     http.Client
}

// urlJoin joins parts of a URL by trimming slashes and re-joining with a single slash between parts.
func urlJoin(args ...string) string {
	var trimmed []string
	for _, arg := range args {
		trimmed = append(trimmed, strings.Trim(arg, "/"))
	}
	return strings.Join(trimmed, "/")
}

// New creates a Connection and authenticates to the API.
func New(version, key, secret, practiceid string) (conn *Connection, err error) {
	conn = &Connection{
		key:        key,
		secret:     secret,
		version:    version,
		practiceid: practiceid,
		token:      "",
		basepath:   "https://api.athenahealth.com/",
		client:     http.Client{},
	}

	err = conn.authenticate()
	return conn, err
}

// authenticate perfoms basic access authentication to the API and stores the token for later use.
func (conn *Connection) authenticate() (err error) {
	authPrefixes := map[string]string{
		"v1":           "/oauth",
		"preview1":     "/oauthpreview",
		"openpreview1": "/oauthopenpreview",
	}
	authUrl := urlJoin(conn.basepath, authPrefixes[conn.version], "/token")
	parameters := url.Values{
		"grant_type": {"client_credentials"},
	}

	req, err := http.NewRequest("POST", authUrl, bytes.NewBufferString(parameters.Encode()))
	if err != nil {
		return err
	}

	req.Header.Add("Content-Type", "application/x-www-form-urlencoded")
	req.SetBasicAuth(conn.key, conn.secret)

	response, err := conn.call(req)
	if err != nil {
		return err
	}

	contents := response.(map[string]interface{})
	token := contents["access_token"]
	conn.token = token.(string)
	return nil
}

// call is used to abstract away the request sending, response reading, and JSON unmarshalling of an
// API call.
func (conn *Connection) call(req *http.Request) (response interface{}, err error) {
	// This line avoids the "unexpected end of JSON input" and "flate: corrupt input before offset
	// 7" errors.  Reading some responses involves decompressing data with inflate (the complement
	// to deflate compression), so we include in the headers that we accept that encoding.
	req.Header.Add("Accept-Encoding", "deflate")
	resp, err := conn.client.Do(req)
	if err != nil {
		return nil, err
	}

	body, err := ioutil.ReadAll(resp.Body)
	defer resp.Body.Close()
	if err != nil && resp.StatusCode != 400 { // HTTP 400 Not Authorized
		return nil, err
	}

	var decoded interface{}
	err = json.Unmarshal(body, &decoded)
	if err != nil {
		return nil, err
	}

	return decoded, nil
}

// authorizedCall is used to abstract away including the access token in the request.  If an error
// occurs during the call, the request is retried once.
func (conn *Connection) authorizedCall(verb, path string, parameters, headers map[string]string, secondcall bool) (response interface{}, err error) {
	body := url.Values{}
	for k, v := range parameters {
		body.Add(k, v)
	}

	req, err := http.NewRequest(verb, path, bytes.NewBufferString(body.Encode()))
	if (err != nil) && secondcall {
		return nil, err
	}

	req.Header.Add("Authorization", fmt.Sprintf("Bearer %s", conn.token))
	for k, v := range headers {
		req.Header.Add(k, v)
	}
	resp, err := conn.call(req)
	if (err != nil) && !secondcall {
		conn.authenticate()
		return conn.authorizedCall(verb, path, parameters, headers, true)
	}
	return resp, err
}

// GET performs an HTTP GET request to the API.
func (conn *Connection) GET(path string, parameters, headers map[string]string) (response interface{}, err error) {
	query := ""
	if len(parameters) != 0 {
		q := url.Values{}
		for k, v := range parameters {
			q.Add(k, v)
		}
		query = "?" + q.Encode()
	}
	reqUrl := urlJoin(conn.basepath, conn.version, conn.practiceid, path, query)
	return conn.authorizedCall("GET", reqUrl, make(map[string]string), headers, false)
}

// POST performs an HTTP POST request to the API.
func (conn *Connection) POST(path string, parameters, headers map[string]string) (response interface{}, err error) {
	reqUrl := urlJoin(conn.basepath, conn.version, conn.practiceid, path)
	if parameters == nil {
		parameters = make(map[string]string)
	}
	if headers == nil {
		headers = make(map[string]string)
	}
	headers["Content-Type"] = "application/x-www-form-urlencoded"
	return conn.authorizedCall("POST", reqUrl, parameters, headers, false)
}

// PUT performs an HTTP PUT request to the API.
func (conn *Connection) PUT(path string, parameters, headers map[string]string) (response interface{}, err error) {
	reqUrl := urlJoin(conn.basepath, conn.version, conn.practiceid, path)
	if parameters == nil {
		parameters = make(map[string]string)
	}
	if headers == nil {
		headers = make(map[string]string)
	}
	headers["Content-Type"] = "application/x-www-form-urlencoded"
	return conn.authorizedCall("PUT", reqUrl, parameters, headers, false)
}

// DELETE performs an HTTP DELETE request to the API.
func (conn *Connection) DELETE(path string, parameters, headers map[string]string) (response interface{}, err error) {
	query := ""
	if len(parameters) != 0 {
		q := url.Values{}
		for k, v := range parameters {
			q.Add(k, v)
		}
		query = "?" + q.Encode()
	}
	reqUrl := urlJoin(conn.basepath, conn.version, conn.practiceid, path, query)

	if headers == nil {
		headers = make(map[string]string)
	}
	return conn.authorizedCall("DELETE", reqUrl, make(map[string]string), headers, false)
}

// Req contains the arguments for an HTTP request.
type Req struct {
	Path    string
	Params  map[string]string
	Headers map[string]string
}

// GETs performs an HTTP GET request to the API.
func (conn *Connection) GETs(args Req) (response interface{}, err error) {
	return conn.GET(args.Path, args.Params, args.Headers)
}

// POSTs performs an HTTP POST request to the API.
func (conn *Connection) POSTs(args Req) (response interface{}, err error) {
	return conn.POST(args.Path, args.Params, args.Headers)
}

// PUTs performs an HTTP PUT request to the API.
func (conn *Connection) PUTs(args Req) (response interface{}, err error) {
	return conn.PUT(args.Path, args.Params, args.Headers)
}

// DELETEs performs an HTTP DELETE request to the API.
func (conn *Connection) DELETEs(args Req) (response interface{}, err error) {
	return conn.DELETE(args.Path, args.Params, args.Headers)
}

// Token returns the current access token.
func (conn *Connection) Token() (token string) {
	return conn.token
}
