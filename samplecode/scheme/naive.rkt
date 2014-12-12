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

(require openssl)
(require net/base64)
(require net/http-client)
(require net/url-connect)
(require net/uri-codec)
(require json)
(require racket/pretty)

(define key "CHANGEME: YOUR_API_KEY")
(define secret "CHANGEME: YOUR_API_SECRET")
(define api-version "preview1")
(define practiceid "000000")

;; Friends don't let friends ignore SSL
(let ([context (ssl-make-client-context)])
  (current-https-protocol context)
  (ssl-set-verify! context #t)
  (ssl-load-default-verify-sources! context))

(define conn (http-conn-open "api.athenahealth.com" #:ssl? #t))

;; Just to keep things readable for the the one time we have to use this
(define (b64encode str) (bytes->string/utf-8 (base64-encode (string->bytes/utf-8 str) #"")))

(define auth-prefixes
  (make-hash 
   (list (cons "v1" "/oauth")
         (cons "preview1" "/oauthpreview")
         (cons "openpreview1" "/oauthopenpreview"))))


(define token 
  (let-values 
      ([(status headers port) 
        (http-conn-sendrecv! 
         conn 
         (string-append (hash-ref auth-prefixes api-version) "/token")
         #:method "POST" 
         #:data "grant_type=client_credentials"
         #:headers (list 
                    "Content-Type: application/x-www-form-urlencoded"
                    (string-append "Authorization: Basic " (b64encode (string-append key ":" secret)))))])
    (let ([access-token (hash-ref (read-json port) 'access_token)])
      (close-input-port port)
      access-token)))

(displayln token)


(define departments 
  (let* ([path (string-append "/" api-version "/" practiceid "/departments")]
         [params '((limit . "1"))]
         [headers (list (string-append "Authorization: Bearer " token))]
         [url (string-append path "?" (alist->form-urlencoded params))])
    (let-values ([(status headers port)
                  (http-conn-sendrecv!
                   conn
                   url
                   #:method "GET"
                   #:headers headers)])
      (let ([response (read-json port)])
        (close-input-port port)
        response))))

(pretty-print departments)


(define note
  (let* ([path (string-append "/" api-version "/" practiceid "/appointments/1/notes")]
         [params '((notetext . "Scheming"))]
         [headers (list 
                   (string-append "Authorization: Bearer " token)
                   "Content-type: application/x-www-form-urlencoded")])
    (let-values ([(status headers port)
                  (http-conn-sendrecv!
                   conn
                   path
                   #:data (alist->form-urlencoded params)
                   #:method "POST"
                   #:headers headers)])
      (let ([response (read-json port)])
        (close-input-port port)
        response))))

(pretty-print note)


(http-conn-close! conn)
