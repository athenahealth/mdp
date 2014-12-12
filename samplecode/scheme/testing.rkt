;;    Copyright 2014 athenahealth, Inc.
;;
;;   Licensed under the Apache License, Version 2.0 (the "License"); you
;;   may not use this file except in compliance with the License.  You
;;   may obtain a copy of the License at
;;
;;       http://www.apache.org/licenses/LICENSE-2.0
;;
;;   Unless required by applicable law or agreed to in writing, software
;;   distributed under the License is distributed on an "AS IS" BASIS,
;;   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
;;   implied.  See the License for the specific language governing
;;   permissions and limitations under the License.

(require "athenahealthapi.rkt")
(require racket/pretty)
(require racket/date)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define key "CHANGEME: YOUR_API_KEY")
(define secret "CHANGEME: YOUR_API_SECRET")
(define practiceid 000000)
(define api-version "preview1")

(define api (make-object api-connection% key secret api-version practiceid))

;; If you want to change which practice you're working with after initialization, this is how.
;; (set-field! practiceid api 000000)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GET without parameters
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(let ([customfields (send api GET "/customfields")])
  (displayln "Custom fields:")
  (pretty-print (hash-keys (car customfields)))
  (newline))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GET with parameters
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define appointment
  (let* ([now (current-date)]
         [month (date-month now)]
         [day (date-day now)]
         [year (date-year now)]
         [today (string-join (map number->string (list month day year)) "/")]
         [nextyear (string-join (map number->string (list month day (add1 year))) "/")]
         [params (make-hash (list (cons "departmentid" "82")
                                  (cons "startdate" today)
                                  (cons "enddate" nextyear)
                                  (cons "appointmenttypeid" "2")
                                  (cons "limit" "1")))]
         [response (send api GET "/appointments/open" #:params params)]
         [appointment (car (hash-ref response 'appointments))])
    (displayln "Open appointment:")
    (pretty-print appointment)
    (newline)
    appointment))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; POST with parameters
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define new-patient-id
  (let* ([patient-info (make-hash (list 
                                   (cons "lastname" "Foo")
                                   (cons "firstname" "Jason")
                                   (cons "address1" "123 Any Street")
                                   (cons "city" "Cambridge")
                                   (cons "countrycode3166" "US")
                                   (cons "departmentid" "1")
                                   (cons "dob" "6/18/1987")
                                   (cons "language6392code" "declined")
                                   (cons "maritalstatus" "S")
                                   (cons "race" "declined")
                                   (cons "sex" "M")
                                   (cons "ssn" "*****1234")
                                   (cons "zip" "02139")))]
         [response (send api POST "/patients" #:params patient-info)]
         [patient-id (hash-ref (car response) 'patientid)])
    (displayln "New patient id:")
    (pretty-print patient-id)
    (newline)
    patient-id))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PUT with parameters
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(let* ([appointment-info (make-hash (list
                                     (cons "appointmenttypeid" "82")
                                     (cons "departmentid" "1")
                                     (cons "patientid" new-patient-id)))]
       [path (path-join "/appointments" (hash-ref appointment 'appointmentid))]
       [booked (send api PUT path #:params appointment-info)])
  (displayln "Response to booking appointment:")
  (pretty-print booked)
  (newline))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; POST without parameters
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(let* ([path (path-join "/appointments" (hash-ref appointment 'appointmentid) "/checkin")]
       [check-in (send api POST path)])
  (displayln "Response to check-in:")
  (pretty-print check-in)
  (newline))

(sleep 1)                               ; Otherwise we go over QPS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DELETE with parameters
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(let* ([path (path-join "/patients" new-patient-id "/chartalert")]
       [params (make-hash (list (cons "departmentid" "1")))]
       [chart-alert (send api DELETE path #:params params)])
  (displayln "Removed chart alert:")
  (pretty-print chart-alert)
  (newline))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DELETE without parameters
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(let* ([path (path-join "/appointments" new-patient-id)]
       [removed-appointment (send api DELETE path)])
  (displayln "Removed appointment:")
  (pretty-print removed-appointment)
  (newline))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; There are no PUTs without parameters
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Error conditions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(let* ([response (send api GET "/nothing/at/this/path")])
  (displayln "GET /nothing/at/this/path")
  (pretty-print response)
  (newline))

(let* ([response (send api GET "/appointments/open")])
  (displayln "Missing parameters:")
  (pretty-print response)
  (newline))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Testing token refresh
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; This test takes an hour to run, so it's disabled by default. Change #f to #t to run it.
(if #f
    (begin
      (displayln (string-append "Old token: " (send api get-token)))
      
      ;; wait 3600 seconds = 1 hour for token to expire
      (sleep 3600)
      
      (send api GET "/departments")
      
      (displayln (string-append "New token: " (send api get-token))))
    (exit))
