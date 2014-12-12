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
	"athenahealth.com/athenahealthapi"
	"fmt"
	"strings"
	"time"
)

func pathJoin(args ...string) string {
	var out []string
	for _, arg := range args {
		out = append(out, "/"+strings.Trim(arg, "/"))
	}
	return strings.Join(out, "")
}

func main() {
	key := "CHANGEME: YOUR_API_KEY"
	secret := "CHANGEME: YOUR_API_SECRET"
	version := "preview1"
	practiceid := "000000"

	api, err := athenahealthapi.New(version, key, secret, practiceid)
	if err != nil {
		panic(err)
	}

	////////////////////////////////////////////////////////////////////////////////////////////////
	// GET without parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	customfields, err := api.GET("/customfields", nil, nil)
	if err != nil {
		panic(err)
	}
	fmt.Println("Custom fields:")
	for _, v := range customfields.([]interface{}) {
		field := v.(map[string]interface{})["name"]
		fmt.Println(field)
	}
	fmt.Println()

	////////////////////////////////////////////////////////////////////////////////////////////////
	// GET with parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	today := time.Now()
	nextyear := today.AddDate(1, 0, 0)
	dateformat := "01/02/2006"

	search := map[string]string{
		"departmentid":      "82",
		"startdate":         today.Format(dateformat),
		"enddate":           nextyear.Format(dateformat),
		"appointmenttypeid": "2",
		"limit":             "1",
	}

	openAppts, err := api.GET("/appointments/open", search, nil)
	if err != nil {
		panic(err)
	}

	appts := openAppts.(map[string]interface{})["appointments"]
	apptTemp := appts.([]interface{})[0]
	appt := map[string]interface{}(apptTemp.(map[string]interface{}))
	fmt.Println("Open appointment:")
	fmt.Println(appt)
	fmt.Println()

	appt["appointmenttime"] = appt["starttime"]
	appt["appointmentdate"] = appt["date"]
	delete(appt, "starttime")
	delete(appt, "date")

	////////////////////////////////////////////////////////////////////////////////////////////////
	// POST with parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	patientInfo := map[string]string{
		"lastname":         "Foo",
		"firstname":        "Jason",
		"address1":         "123 Any Street",
		"city":             "Cambridge",
		"countrycode3166":  "US",
		"departmentid":     "1",
		"dob":              "6/18/1987",
		"language6392code": "declined",
		"maritalstatus":    "S",
		"race":             "declined",
		"sex":              "M",
		"ssn":              "*****1234",
		"zip":              "02139",
	}

	newPatient, err := api.POST("/patients", patientInfo, nil)
	if err != nil {
		panic(err)
	}
	newPatientID := newPatient.([]interface{})[0].(map[string]interface{})["patientid"]
	fmt.Println("New patient ID:")
	fmt.Println(newPatientID)
	fmt.Println()

	////////////////////////////////////////////////////////////////////////////////////////////////
	// PUT with parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	appointmentInfo := map[string]string{
		"appointmenttypeid": "82",
		"departmentid":      "1",
		"patientid":         newPatientID.(string),
	}

	_ = appointmentInfo
	booked, err := api.PUT(pathJoin("/appointments", appt["appointmentid"].(string)), appointmentInfo, nil)
	if err != nil {
		panic(err)
	}
	fmt.Println("Response to booking appointment:")
	fmt.Println(booked)
	fmt.Println()

	////////////////////////////////////////////////////////////////////////////////////////////////
	// POST without parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	checkedIn, err := api.POST(pathJoin("/appointments", appt["appointmentid"].(string), "/checkin"), nil, nil)
	if err != nil {
		panic(err)
	}
	fmt.Println("Response to check-in:")
	fmt.Println(checkedIn)
	fmt.Println()

	////////////////////////////////////////////////////////////////////////////////////////////////
	// DELETE with parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	removedChartAlert, err := api.DELETE(pathJoin("/patients", newPatientID.(string), "chartalert"), map[string]string{"departmentid": "1"}, nil)
	if err != nil {
		panic(err)
	}
	fmt.Println("Removed chart alert:")
	fmt.Println(removedChartAlert)
	fmt.Println()

	////////////////////////////////////////////////////////////////////////////////////////////////
	// DELETE without parameters
	////////////////////////////////////////////////////////////////////////////////////////////////
	removedAppointment, err := api.DELETE(pathJoin("/appointments", appt["appointmentid"].(string)), nil, nil)
	if err != nil {
		panic(err)
	}
	fmt.Println("Removed appointment:")
	fmt.Println(removedAppointment)
	fmt.Println()

	////////////////////////////////////////////////////////////////////////////////////////////////
	// There are no PUTs without parameters
	////////////////////////////////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////////////////////////////////
	// Error conditions
	////////////////////////////////////////////////////////////////////////////////////////////////
	badPath, err := api.GET("/nothing/at/this/path", nil, nil)
	if err != nil {
		panic(err)
	}
	fmt.Println("GET /nothing/at/this/path:")
	fmt.Println(badPath)
	missingParameters, err := api.GET("/appointments/open", nil, nil)
	if err != nil {
		panic(err)
	}
	fmt.Println("Response to missing parameters:")
	fmt.Println(missingParameters)
	fmt.Println()

	////////////////////////////////////////////////////////////////////////////////////////////////
	// Testing token refresh
	////////////////////////////////////////////////////////////////////////////////////////////////
	// NOTE: This takes an hour to run, so it's disabled by default. Change false to true to run it.
	if false {
		fmt.Println("Old token:", api.Token())

		_, err = api.GET("/departments", nil, nil)
		if err != nil {
			panic(err)
		}
		// Wait 1 hour for token to expire
		time.Sleep(1 * time.Hour)

		_, err = api.GET("/departments", nil, nil)
		if err != nil {
			panic(err)
		}
		fmt.Println("New token:", api.Token())
	}
}
