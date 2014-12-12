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


;; This module contains utilities for communicating with the More Disruption Please API.

(module athenahealthapi racket
  (provide api-connection%
           path-join
           urlencode/pair
           urlencode/hash)

  (require json
           net/uri-codec
           net/url-connect
           net/base64
           net/http-client
           openssl
           racket/class) 

  ;; Create an SSL context, assign it to be used for HTTPS and populate it
  (let ([context (ssl-make-client-context)])
    (current-https-protocol context)
    (ssl-set-verify! context #t)
    (ssl-load-default-verify-sources! context))

  (define (urlencode/pair pair) 
    (let ([pair (list (car pair) (cdr pair))]) 
      (string-join (map uri-encode pair) "=")))

  (define (urlencode/hash parameters)
    (string-join (map urlencode/pair (hash->list parameters)) "&"))
  
  (define (pair->header pair)
    (string-append (car pair) ": " (cdr pair)))

  (define (hash->headers headers)
    (map pair->header (hash->list headers)))
  
  (define (path-join . parts)
    (apply string-append (map (lambda (x) (string-append "/" (string-trim x "/"))) parts)))
  
  (define (hash-merge first . rest)
    (let ([output (hash-copy first)])
      (for ([next rest])
        (hash-for-each next (lambda (key val) (hash-set! output key val))))
      output))
  
  ;; Just to keep things readable for the the one time we have to use this
  (define (b64encode str) (bytes->string/utf-8 (base64-encode (string->bytes/utf-8 str) #"")))
  
  (define auth-prefixes
    (make-hash 
     (list (cons "v1" "/oauth")
           (cons "preview1" "/oauthpreview")
           (cons "openpreview1" "/oauthopenpreview"))))
  
  ;; This class abstracts away the HTTP connection and basic authentication from API calls.
  ;; 
  ;; When an object of this class is constructed, it attempts to authenticate (using basic
  ;; authentication) using the key, secret, and version specified.  It stores the access token for
  ;; later use.
  ;;
  ;; Whenever any of the HTTP request methods are called (GET, POST, etc.), the arguments are
  ;; converted into the proper form for the request.  The result is decoded from JSON and returned.
  ;; 
  ;; The HTTP request methods take a mandatory path argument (string) and optional params and
  ;; headers arguments (both string-string hashes).  The API version associated with this connection
  ;; is prepended to the path along with the practice ID (if set).  The response is decoded from
  ;; JSON and returned.
  ;; 
  ;; If an API call returns 401 Not Authorized, a new access token is obtained and the request is
  ;; retried once.
  (define api-connection%
    (class object%
      (super-new)
      (init key)
      (init secret)
      (init api-version)
      (init-field [practiceid 0])

      (define host "api.athenahealth.com")
      (define connection (http-conn-open host #:ssl? #t))
      (define token "")
      
      (public GET POST PUT DELETE get-token)

      ;; Sends an HTTP request and returns the JSON-decoded response.
      (define (call verb path body headers)
        (let* ([new-body (urlencode/hash body)]
               ;; The HTTP client expects a "deflate" encoding, but doesn't request it by default,
               ;; so we add it to default-headers.
               [default-headers (make-hash (list (cons "Accept-Encoding" "deflate")))]
               [new-headers (hash-merge default-headers headers)])
          (let-values
              ([(status headers port)
                (http-conn-sendrecv!
                 connection
                 path
                 #:method verb
                 #:data new-body
                 #:headers (hash->headers new-headers))])
            (let ([response (read-json port)])
              (close-input-port port)
              response))))
      
      ;; Uses key and secret to obtain a new access token.
      (define (authenticate)
        (let ([response 
               (call "POST"
                     (path-join (hash-ref auth-prefixes api-version) "/token")
                     (make-hash (list (cons "grant_type" "client_credentials")))
                     (let ([auth (b64encode (string-append key ":" secret))])
                       (make-hash 
                        (list (cons "Content-Type" "application/x-www-form-urlencoded")
                              (cons "Authorization" (string-append "Basic " auth))))))])
          (set! token (hash-ref response 'access_token))))
      
      (define (re-connect) (set! connection (http-conn-open host #:ssl? #t)))
      (define re-authenticate authenticate)
      
      ;; Sends an HTTP request that includes the current access token and returns the JSON-decoded
      ;; response.  If an error occurs, the request is retried by default unless retry? is false.
      (define (authorized-call verb path body headers #:retry? [retry? #t])
        (let* ([new-path (apply path-join (filter (lambda (x) x) (list api-version (number->string practiceid) path)))]
               [default-headers (make-hash (list (cons "Authorization" (string-append "Bearer " token))))]
               [new-headers (hash-merge default-headers headers)])
          (with-handlers ([exn:fail? (lambda (v) 
                                       (re-connect)
                                       (re-authenticate)
                                       (if retry? 
                                           (authorized-call verb path body headers #:retry? #f)
                                           (exit)))])
            (call verb new-path body new-headers))))
      
      ;; Sends a GET request and returns the JSON-decoded response.
      (define (GET path 
                   #:params [params (make-hash)]
                   #:headers [headers (make-hash)])
        (let* ([query (urlencode/hash params)]
               [new-path (if query
                             (string-append path "?" query)
                             path)])
          (authorized-call "GET" new-path (make-hash) headers)))
      
      ;; Sends a POST request and returns the JSON-decoded response.
      (define (POST path 
                   #:params [params (make-hash)]
                   #:headers [headers (make-hash)])
        (let* ([default-headers (make-hash (list (cons "Content-Type" "application/x-www-form-urlencoded")))]
               [new-headers (hash-merge default-headers headers)])
          (authorized-call "POST" path params new-headers)))

      ;; Sends a PUT request and returns the JSON-decoded response.
      (define (PUT path 
                   #:params [params (make-hash)]
                   #:headers [headers (make-hash)])
        (let* ([default-headers (make-hash (list (cons "Content-Type" "application/x-www-form-urlencoded")))]
               [new-headers (hash-merge default-headers headers)])
          (authorized-call "PUT" path params new-headers)))

      ;; Sends a DELETE request and returns the JSON-decoded response.
      (define (DELETE path 
                   #:params [params (make-hash)]
                   #:headers [headers (make-hash)])
        (let* ([query (urlencode/hash params)]
               [new-path (if query
                             (string-append path "?" query)
                             path)])
          (authorized-call "DELETE" new-path (make-hash) headers)))
      
      ;; Private method, since the public get-token can't access token directly.
      (define (current-token) token)
     
      ;; Returns the current access token.
      (define (get-token) (current-token))

      ;; Start the whole thing with authentication.
      (authenticate))))
