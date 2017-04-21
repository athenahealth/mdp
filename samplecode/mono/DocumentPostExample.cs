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

/*******************************************************************************
* This code was submitted by one of our athena partners as an example of how to
* do a document post through the MDP APIs in C#.  It comes with no warranty or
* guarantee to be correct or to work for your use case.  It was meant to try to
* give a starting off point when doing something like this.  Use at your own
* discretion.
******************************************************************************/
using System.Text;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System;
using Athenahealth;
using System.Web;
using Newtonsoft.Json;

public class PDFSend {
    // Procedure to send the pdf:
    public string SendPDFToAthena(string practiceID, string patientID, string appointmentID, string departmentID, string internalNote, bool attachPDFToVisit, byte[] data)
    {
        string version = "{yourVersionHere}"; // preview1, v1, etc
        string key = "{yourKeyHere}";
        string secret = "{yourSecretHere}";

        // This references an api that is pretty much exactly like that found on the
        // athena website for asp.net examples.  Get a token for authentication:
        APIConnection api = new APIConnection(version, key, secret, practiceID);
        string token = api.GetToken();

        // Generate post objects
        Dictionary<string, object> postParameters = new Dictionary<string, object>();
        postParameters.Add("appointmentid", appointmentID);
        postParameters.Add("internalnote", internalNote);

        //automatically close these docs (or leave out if you want them to be open for review)
        postParameters.Add("autoclose", "true");

         //where to attach? You should modify these for your use case
        if (attachPDFToVisit) {postParameters.Add("documentsubclass", "ENCOUNTERDOCUMENT_PROGRESSNOTE"); }
        else { postParameters.Add("documentsubclass", "CLINICALDOCUMENT"); }

        postParameters.Add("file", new FormUpload.FileParameter(data, appointmentID + ".pdf", "application/pdf"));

        // Create request and receive response
        string postURL = "https://api.athenahealth.com/" + version + "/" + practiceID + "/patients/" + patientID + "/documents";
        string userAgent = "Someone";  // The secret sauce: seems meaningless, but userAgent apparently must have a value
        string webResponse = FormUpload.MultipartFormDataPost(postURL, userAgent, postParameters, token);

        return webResponse;
    }
}

// Call the procedure above like this:
public class Sample {
    // gather the patient, appointment, location, and where to attach the chart:
    static public void Main() {
        string practiceID = "{practiceid}";
        string athenaPatientID = "{patientid}";
        string athenaApptID = "{appointmentid}";
        string athenaDepartmentID = "{departmentid}";
        bool attachPDFToVisit = false; // true/false if true, attach to appointment, otherwise attach to patient chart

        string internalNote = "This note seems to be the document name that the user sees";

        // put the pdf into a byte array
        byte[] data;
        string path = "/path/to/pdf-sample.pdf";
        data = File.ReadAllBytes(path);

        PDFSend sender = new PDFSend();
        string reply = sender.SendPDFToAthena(practiceID, athenaPatientID, athenaApptID, athenaDepartmentID, internalNote, attachPDFToVisit, data);

        AthenaDocumentResponse resp = new AthenaDocumentResponse();
        resp = resp.GetResponse(reply);
        if (resp.error != null)
        {
            // error handling here; resp.error gives the detailed message
            Console.WriteLine(resp.error);
        }
        else
        {
            // handle success here: resp.documentid give the athena doc id.  Save or ignore
            Console.WriteLine(reply); // this is just the full json response
        }
    }
}

// FormUpload Class:
// many thanks from brian grinstead
// taken in large part from http://www.briangrinstead.com/blog/multipart-form-post-in-c
public static class FormUpload
{
    private static readonly Encoding encoding = Encoding.UTF8;
    static private Encoding UTF8 = System.Text.Encoding.GetEncoding("utf-8");

    public static string MultipartFormDataPost(string postUrl, string userAgent, Dictionary<string, object> postParameters, string token)
    {
        string formDataBoundary = String.Format("----------{0:N}", Guid.NewGuid());
        string contentType = "multipart/form-data; boundary=" + formDataBoundary;

        byte[] formData = GetMultipartFormData(postParameters, formDataBoundary);

        return PostForm(postUrl, userAgent, contentType, formData, token);
    }

    private static string PostForm(string postUrl, string userAgent, string contentType, byte[] formData, string token)
    {
        HttpWebRequest request = WebRequest.Create(postUrl) as HttpWebRequest;

        if (request == null)
        {
            throw new NullReferenceException("request is not a http request");
        }

        // Set up the request properties.
        request.Method = "POST";
        request.ContentType = contentType;
        request.UserAgent = userAgent;
        request.CookieContainer = new CookieContainer();
        request.ContentLength = formData.Length;

        //authenticate
        request.Headers["Authorization"] = string.Format("Bearer {0}", token);

        // Send the form data to the request.
        using (Stream requestStream = request.GetRequestStream())
        {
            requestStream.Write(formData, 0, formData.Length);
            requestStream.Close();
        }

        StreamReader reader;
        string reply;
        try
        {
            WebResponse response = request.GetResponse();
            reader = new StreamReader(response.GetResponseStream(), UTF8);
            reply = reader.ReadToEnd();
            response.Close();
            return reply;
        }
        catch (WebException wex)
        {
            reader = new StreamReader(wex.Response.GetResponseStream(), UTF8);
            reply = reader.ReadToEnd();
            return reply;
        }
    }

    private static byte[] GetMultipartFormData(Dictionary<string, object> postParameters, string boundary)
    {
        Stream formDataStream = new System.IO.MemoryStream();
        bool needsCLRF = false;

        foreach (var param in postParameters)
        {
            // Add a CRLF to allow multiple parameters to be added.
            // Skip it on the first parameter, add it to subsequent parameters.
            if (needsCLRF)
                formDataStream.Write(encoding.GetBytes("\r\n"), 0, encoding.GetByteCount("\r\n"));

            needsCLRF = true;

            if (param.Value is FileParameter)
            {
                FileParameter fileToUpload = (FileParameter)param.Value;

                // Add just the first part of this param, since we will write
                // the file data directly to the Stream
                string header = string.Format("--{0}\r\nContent-Disposition: form-data; name=\"ATTACHMENTCONTENTS\"; filename=\"{2}\"\r\nContent-Type: {3}\r\n\r\n",
                    boundary,
                    param.Key,
                    fileToUpload.FileName ?? param.Key,
                    fileToUpload.ContentType ?? "application/octet-stream");

                formDataStream.Write(encoding.GetBytes(header), 0, encoding.GetByteCount(header));

                // Write the file data directly to the Stream, rather than serializing it to a string.
                formDataStream.Write(fileToUpload.File, 0, fileToUpload.File.Length);
            }
            else
            {
                string postData = string.Format("--{0}\r\nContent-Disposition: form-data; name=\"{1}\"\r\n\r\n{2}",
                    boundary,
                    param.Key,
                    param.Value);
                formDataStream.Write(encoding.GetBytes(postData), 0, encoding.GetByteCount(postData));
            }
        }

        // Add the end of the request.  Start with a newline
        string footer = "\r\n--" + boundary + "--\r\n";
        formDataStream.Write(encoding.GetBytes(footer), 0, encoding.GetByteCount(footer));

        // Dump the Stream into a byte[]
        formDataStream.Position = 0;
        byte[] formData = new byte[formDataStream.Length];
        formDataStream.Read(formData, 0, formData.Length);
        formDataStream.Close();

        return formData;
    }

    public class FileParameter
    {
        public byte[] File { get; set; }
        public string FileName { get; set; }
        public string ContentType { get; set; }
        public FileParameter(byte[] file) : this(file, null) { }
        public FileParameter(byte[] file, string filename) : this(file, filename, null) { }
        public FileParameter(byte[] file, string filename, string contenttype)
        {
            File = file;
            FileName = filename;
            ContentType = contenttype;
        }
    }
}

// AthenaResponse Class:
public class AthenaDocumentResponse
{
    public string documentid { get; set; }
    public string missingfields { get; set; }
    public string error { get; set; }

    public AthenaDocumentResponse GetResponse(string jsonAsString)
    {
        AthenaDocumentResponse resp = new AthenaDocumentResponse();
        resp = JsonConvert.DeserializeObject<AthenaDocumentResponse>(jsonAsString);
        return resp;
    }
}

