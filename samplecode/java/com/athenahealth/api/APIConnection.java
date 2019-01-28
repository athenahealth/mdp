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
package com.athenahealth.api;

import java.util.Collections;
import java.util.Map;
import java.util.regex.Pattern;

import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLSocketFactory;

import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.Charset;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.UnsupportedEncodingException;
import java.io.Writer;
import java.io.IOException;
import org.apache.commons.codec.binary.Base64;
import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;

/**
 * This class abstracts away the HTTP connection and basic authentication from API calls.
 *
 * When an object of this class is constructed, it attempts to authenticate (using basic
 * authentication) using the key, secret, and version specified.  It stores the access token for
 * later use.
 *
 * Whenever any of the HTTP request methods are called (GET, POST, etc.), the arguments are
 * converted into the proper form for the request.  The result is decoded from JSON and returned as
 * either a JSONObject or JSONArray.
 *
 * The HTTP request methods each have three signatures corresponding to common ways of making
 * requests: (1) just a URL, (2) URL with parameters, (3) URL with parameters and headers.  Each of
 * these methods prepends the specified API version to the URL.  If the practice ID is set, it is
 * also added.
 *
 * If an API call returns 401 Not Authorized, a new access token is obtained and the request is
 * retried.
 */
public class APIConnection {
	private final String key;
	private final String secret;
	private final String version;
	private String practiceId;
	private String base_url;
	private String token;
	private Charset httpAuthEncoding = Charset.forName("UTF-8");

	/**
	 * Optional customized SSLSocketFactory.
	 */
	private SSLSocketFactory _sslSocketFactory;
	private int _socketConnectTimeout =  5 * 1000;
	private int _socketReadTimeout    = 20 * 2000;

	// http://stackoverflow.com/q/507602
	private static final Map<String, String> authPrefixes;
	static {
		Map<String, String> tempMap = new HashMap<String, String>();
		tempMap.put("v1", "/oauth");
		tempMap.put("preview1", "/oauthpreview");
		tempMap.put("openpreview1", "/oauthopenpreview");
		authPrefixes = Collections.unmodifiableMap(tempMap);
	}

	/**
	 * Connect to the specified API version using key and secret.
	 *
	 * @param version API version to access
	 * @param key     client key (also known as ID)
	 * @param secret  client secret
	 */
	public APIConnection(String version, String key, String secret) {
		this(version, key, secret, "");
	}

	/**
	 * Connect to the specified API version using key and secret.
	 *
	 * @param version    API version to access
	 * @param key        client key (also known as ID)
	 * @param secret     client secret
	 * @param practiceId practice ID to use
	 */
	public APIConnection(String version, String key, String secret, String practiceId) {
	    if(!authPrefixes.containsKey(version))
	        throw new IllegalArgumentException("Unknown version: " + version);

	    this.version = version;
		this.key = key;
		this.secret = secret;
		this.practiceId = practiceId;
		this.base_url = "https://api.athenahealth.com";
	}

	/**
	 * Sets the base URL for athenanet.
	 *
	 * @param baseURL The base URL for contacting athenanet.
	 */
	public void setBaseURL(String baseURL)
	{
	    // Remove any trailing slashes
	    if(baseURL != null)
	        while(baseURL.endsWith("/"))
	            baseURL = baseURL.substring(0, baseURL.length() - 1);

	    base_url = baseURL;
	}

    /**
     * Gets the base URL for athenanet.
     *
     * @return The base URL for contacting athenanet.
     */
	public String getBaseURL()
	{
	    return base_url;
	}

	/**
	 * Sets a custom {@link SSLSocketFactory} to be used with this connection.
	 * Allows a client to customize the various protocols and ciphers used,
	 * as well as providing a client TLS certificate if necessary for mutual
	 * authentication.
     *
	 * @param ssf The SSLSocketFactory to use for connections.
	 */
	public void setSSLSocketFactory(SSLSocketFactory ssf) {
	    _sslSocketFactory = ssf;
	}

    /**
     * Gets the custom {@link SSLSocketFactory} being used with this connection.
     */
	public SSLSocketFactory getSSLSocketFactory() {
	    return _sslSocketFactory;
	}

	/**
	 * Sets the socket connection timeout for API connections.
	 * A timeout of zero (0) means "wait indefinitely".
	 *
	 * @param timeout The socket connection timeout, in ms.
	 */
	public void setSocketConnectTimeout(int timeout) {
	    _socketConnectTimeout = timeout;
	}

	/**
     * Gets the socket connection timeout for API connections.
     * A timeout of zero (0) means "wait indefinitely".
     *
     * @return The socket connection timeout, in ms.
     */
	public int getSocketConnectTimeout() {
	    return _socketConnectTimeout;
	}

	/**
     * Sets the socket read timeout for API connections.
     * A timeout of zero (0) means "wait indefinitely".
     *
     * @param timeout The socket connection timeout, in ms.
     */
    public void setSocketReadTimeout(int timeout) {
        _socketReadTimeout = timeout;
    }

    /**
     * Gets the socket read timeout for API connections.
     * A timeout of zero (0) means "wait indefinitely".
     *
     * @return The socket connection timeout, in ms.
     */
    public int getSocketReadTimeout() {
        return _socketReadTimeout;
    }

    /**
     * Set the character encoding to use when preparing HTTP authentication
     * credentials using base64 encoding. The default is UTF-8, as per
     * athenaNET's documentation.
     *
     * @param encoding The character encoding to use.
     */
    public void setHTTPAuthEncoding(Charset encoding) {
        if(encoding == null)
            throw new IllegalArgumentException("Encoding must not be null");

        httpAuthEncoding = encoding;
    }

    /**
     * Set the character encoding to use when preparing HTTP authentication
     * credentials using base64 encoding. The default is UTF-8, as per
     * athenaNET's documentation.
     *
     * @param encoding The character encoding to use.
     */
    public void setHTTPAuthEncoding(String encoding) {
        setHTTPAuthEncoding(Charset.forName(encoding));
    }

    /**
     * Get the character encoding that will be used when preparing HTTP
     * authentication credentials using base64 encoding.
     * The default is UTF-8, as per athenaNET's documentation.
     */
    public Charset getHTTPAuthEncoding() {
        return httpAuthEncoding;
    }

    private HttpURLConnection openConnection(URL url) throws IOException {
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        if(conn instanceof HttpsURLConnection) {
            SSLSocketFactory ssf = getSSLSocketFactory();
            if(ssf != null)
                ((HttpsURLConnection)conn).setSSLSocketFactory(ssf);
        }

        conn.setConnectTimeout(getSocketConnectTimeout());
        conn.setReadTimeout(getSocketReadTimeout());

        return conn;
	}

	/**
	 * Authenticate to the athenahealth API service.
	 */
	public void authenticate() throws AthenahealthException {
	    BufferedReader rd = null;
	    Writer wr = null;
	    try {
	        // The URL to authenticate to is determined by the version of the API specified at
	        // construction.
	        final URL url = new URL(joinPath(getBaseURL(), authPrefixes.get(version), "/token"));
	        final HttpURLConnection conn = openConnection(url);
	        conn.setRequestMethod("POST");

	        final String auth = Base64.encodeBase64String((key + ":" + secret).getBytes(getHTTPAuthEncoding()));

	        conn.setRequestProperty("Authorization", "Basic " + auth);

	        conn.setDoOutput(true);

	        wr = new OutputStreamWriter(conn.getOutputStream(), "UTF-8");
	        wr.write(encodeUrl(Collections.singletonMap("grant_type", "client_credentials")));
	        wr.flush();
	        wr.close();

	        if(503 == conn.getResponseCode())
	            throw new UnavailableException(conn.getResponseMessage());

	        final ResponseInfo info = getResponseInfo(conn, "UTF-8");

            rd = new BufferedReader(new InputStreamReader(conn.getInputStream(), info.getCharset()));
	        final StringBuilder sb = new StringBuilder();
	        String line;
	        while ((line = rd.readLine()) != null) {
	            sb.append(line);
	        }
	        rd.close();

	        final JSONObject response = new JSONObject(sb.toString());
	        token = response.get("access_token").toString();
	    }
        catch (MalformedURLException mue)
        {
            throw new AuthenticationException("Error authenticating with server", mue);
        }
	    catch (IOException ioe)
	    {
	        throw new CommunicationException("Error authenticating with server", ioe);
	    }
	    finally
	    {
            if(wr != null) try { wr.close(); }
            catch (IOException ioe) { ioe.printStackTrace(); }

            if(rd != null) try { rd.close(); }
	        catch (IOException ioe) { ioe.printStackTrace(); }
	    }
	}

	private final Pattern PATH_SEPARATORS = Pattern.compile("^/+|/+$");

	/**
	 * Join arguments into a valid path.
	 *
	 * @param args parts of the path to join
	 * @return the joined path
	 */
	private String joinPath(String ... args) {
		final StringBuilder sb = new StringBuilder();
		boolean first = true;
		for (String arg : args) {
		    String current = PATH_SEPARATORS.matcher(arg).replaceAll("");

			// Skip empty strings
			if (current.isEmpty()) {
				continue;
			}

			if (first) {
				first = false;
			} else {
				sb.append("/");
			}

			sb.append(current);
		}

		return sb.toString();
	}

	/**
	 * Convert parameters into a URL query string.
	 *
	 * @param parameters keys and values to encode
	 * @return the query string
	 */
	private String encodeUrl(Map<?, ?> parameters) {
		final StringBuilder sb = new StringBuilder();
		boolean first = true;

		try {
		    for (Map.Entry<?,?> pair : parameters.entrySet()) {
		        String k = pair.getKey().toString();
		        String v = String.valueOf(pair.getValue());

		        if (first) {
		            first = false;
		        } else {
		            sb.append("&");
		        }
                sb.append(URLEncoder.encode(k, "UTF-8"))
                  .append('=')
                  .append(URLEncoder.encode(v, "UTF-8"));
		    }
		} catch (UnsupportedEncodingException uee) {
		    throw new InternalError("Java suddenly does not support UTF-8 character encoding");
		}

		return sb.toString();
	}


	/**
	 * Make the API call.
	 *
	 * This method abstracts away the connection, streams, and readers necessary to make an HTTP
	 * request.  It also adds in the Authorization header and token.
	 *
	 * @param method     HTTP method to use
	 * @param path       URI to find
	 * @param parameters key-value pairs of request parameters
	 * @param headers    key-value pairs of request headers
	 * @param secondCall true if this is the retried request
	 * @return the JSON-decoded response
	 *
	 * @throws AthenahealthException If there is an error making the call.
	 *                               API-level errors are reported in the return-value.
	 */
	private Object call(String method, String path, Map<String, String> parameters, Map<String, String> headers, boolean secondCall) throws AthenahealthException {
	    Writer wr = null;
	    BufferedReader rd = null;
	    BufferedInputStream in = null;
	    try {
	        // Join up a url and open a connection
	        URL url = new URL(joinPath(getBaseURL(), version, practiceId, path));
            HttpURLConnection conn = openConnection(url);
	        conn.setRequestMethod(method);

	        conn.setRequestProperty("Content-Type",  "application/x-www-form-urlencoded; charset=UTF-8");

	        // Set the Authorization header using the token, then do the rest of the headers
	        conn.setRequestProperty("Authorization", "Bearer " + token);
	        if (headers != null) {
	            for (Map.Entry<String, String> pair : headers.entrySet()) {
	                conn.setRequestProperty(pair.getKey(), pair.getValue());
	            }
	        }

	        // Set the request parameters, if there are any
	        if (parameters != null) {
	            conn.setDoOutput(true);
	            wr = new OutputStreamWriter(conn.getOutputStream(), "UTF-8");
	            wr.write(encodeUrl(parameters));
	            wr.flush();
	            wr.close();
	        }

	        // If we get a 401, retry once
	        if (conn.getResponseCode() == 401 && !secondCall) {
	            authenticate();
	            return call(method, path, parameters, headers, true);
	        }

	        ResponseInfo info = getResponseInfo(conn, "UTF-8");

	        String contentType = info.getContentType();

	        Object response;
	        // We may have binary data coming back. Only use text-oriented
	        // readers when the stream is not binary.
	        if(contentType != null && contentType.startsWith("image/"))
	        {
                // This is binary data.
	            long contentLength = conn.getContentLengthLong();
	            if(contentLength > Integer.MAX_VALUE)
	                throw new AthenahealthException("Binary response too big: " + contentLength + " > " + Integer.MAX_VALUE);

	            ByteArrayOutputStream baos = new ByteArrayOutputStream((int)contentLength);
	            try {
	                in = new BufferedInputStream(conn.getInputStream());
	            }
	            catch (IOException ioe) {
                    in = new BufferedInputStream(conn.getErrorStream());
	            }
	            byte[] buffer = new byte[4096];
	            int c;
	            while ((c = in.read(buffer)) != -1)
	                baos.write(buffer, 0, c);

                baos.close();

                response = new JSONObject()
                        .put("binary", "true")
                        .put("contentType", conn.getContentType())
                        .put("contents", baos.toByteArray());
	        }
	        else
	        {
	            // The API response is in the input stream on success and the error stream on failure.
	            try {
	                rd = new BufferedReader(new InputStreamReader(conn.getInputStream(), info.getCharset()));
	            }
	            catch (IOException e) {
	                rd = new BufferedReader(new InputStreamReader(conn.getErrorStream(), info.getCharset()));
	            }
	            StringBuilder sb = new StringBuilder();
	            String line;
	            while ((line = rd.readLine()) != null) {
	                sb.append(line);
	            }
	            rd.close();

	            String rawResponse = sb.toString();

	            if(conn.getResponseCode() == 503)
	                throw new UnavailableException("Service Temporarily Unavailable: " + rawResponse);

	            if(contentType == null)
	                throw new AthenahealthException("Expected application/json response, got <null> instead.");

	            if(!"application/json".equals(contentType))
	            {
	                if("text/xml".equals(contentType)
	                   && null != rawResponse
	                   && "<h1>Gateway Timeout</h1>".equals(rawResponse))
	                    throw new CommunicationException("Service Temporarily Unavailable: " + rawResponse);
	                else
	                    throw new AthenahealthException("Expected application/json response, got "
	                            + contentType + " instead."
	                            + " Content=" + rawResponse + "; response code=" + conn.getResponseCode());
	            }

	            // If it won't parse as an object, it'll parse as an array.
	            try {
	                response = new JSONObject(rawResponse);
	            }
	            catch (JSONException e) {
	                try {
	                    response = new JSONArray(rawResponse);
	                }
	                catch (JSONException e2)
	                {
	                    if(Boolean.getBoolean("com.athenahealth.api.dump-response-on-JSON-error"))
	                    {
	                        System.err.println("Server response code: " + conn.getResponseCode());
	                        Map<String,List<String>> responseHeaders = conn.getHeaderFields();
	                        for(Map.Entry<String,List<String>> header : responseHeaders.entrySet())
	                            for(String value : header.getValue())
	                            {
	                                if(header.getKey() == null || header.getKey().isEmpty())
	                                    System.err.println("Status: " + value);
	                                else
	                                    System.err.println(header.getKey() + "=" + value);
	                            }
	                    }
	                    throw new AthenahealthException("Cannot parse response from server as JSONObject or JSONArray: " + rawResponse, e2);
	                }
	            }
	        }

	        return response;
	    }
	    catch (MalformedURLException mue)
	    {
	        throw new AthenahealthException("Invalid URL", mue);
	    }
        catch (IOException ioe)
        {
            throw new CommunicationException("I/O error during call", ioe);
        }
        finally
        {
            if(wr != null) try { wr.close(); }
            catch (IOException ioe) { ioe.printStackTrace(); }

            if(in != null) try { in.close(); }
            catch (IOException ioe) { ioe.printStackTrace(); }

            if(rd != null) try { rd.close(); }
            catch (IOException ioe) { ioe.printStackTrace(); }
        }
	}

	private static class ResponseInfo
	{
	    String contentType;
	    String charset;

	    ResponseInfo(String contentType, String charset) {
	        this.contentType = contentType;
	        this.charset = charset;
	    }

	    public String getContentType() { return contentType; }
	    public String getCharset() { return charset; }

	    @Override
	    public String toString() {
	        return "{ contentType=" + getContentType() + ", charset=" + getCharset() + " }";
	    }
	}

	private ResponseInfo getResponseInfo(HttpURLConnection conn, String defaultCharset)
	{
	    String contentType = conn.getContentType();
        String charset = defaultCharset;

	    int pos = contentType.indexOf(';');
	    if(pos != -1) {
	        // Use of Locale.US here is justified, since the content-type
	        // header should only contain ASCII characters.
	        String lowerContentType = contentType.toLowerCase(Locale.US);
	        String charsetParameter = "charset=";
	        int charsetParameterLength = charsetParameter.length();
	        int charsetPos = lowerContentType.indexOf(charsetParameter);
	        if(charsetPos != -1) {
	            int len = charsetPos + charsetParameterLength;
	            int end = lowerContentType.indexOf(' ', len);
	            // Use original contentType to get original capitalization
	            if(end < 0)
	                charset = contentType.substring(len);
	            else
	                charset = contentType.substring(len, end);
	        }
	        contentType = contentType.substring(0, pos).trim();
	    }

	    return new ResponseInfo(contentType, charset);
	}

    @SuppressWarnings("unused")
    private void dumpHeaders(HttpURLConnection conn)
    {
        for(Map.Entry<String,List<String>> entry : conn.getHeaderFields().entrySet())
        {
            System.out.print("Header [");
            if(entry.getKey() == null) // This is the HTTP response line
                System.out.print("Response");
            else
                System.out.print(entry.getKey());

            System.out.print("]=");
            boolean first = true;
            for(String value : entry.getValue()) {
                if(first) first = false;
                else System.out.print(",");
                System.out.print("[");
                System.out.print(value);
                System.out.print("]");
            }
            System.out.println();
        }
    }

	/**
	 * Perform a GET request.
	 *
	 * @param path URI to access
	 * @return the JSON-decoded response
	 *
     * @throws AthenahealthException If there is an error making the call.
     *                               API-level errors are reported in the return-value.
	 */
	public Object GET(String path) throws AthenahealthException {
		return GET(path, null, null);
	}

	/**
	 * Perform a GET request.
	 *
	 * @param path       URI to access
	 * @param parameters the request parameters
	 * @return the JSON-decoded response
	 *
     * @throws AthenahealthException If there is an error making the call.
     *                               API-level errors are reported in the return-value.
	 */
	public Object GET(String path, Map<String, String> parameters) throws AthenahealthException {
		return GET(path, parameters, null);
	}

	/**
	 * Perform a GET request.
	 *
	 * @param path       URI to access
	 * @param parameters the request parameters
	 * @param headers    the request headers
	 * @return the JSON-decoded response
	 *
     * @throws AthenahealthException If there is an error making the call.
     *                               API-level errors are reported in the return-value.
	 */
	public Object GET(String path, Map<String, String> parameters, Map<String, String> headers) throws AthenahealthException {
		String query = "";
		if (parameters != null) {
			query = "?" + encodeUrl(parameters);
		}
		return call("GET", path + query, null, headers, false);
	}


	/**
	 * Perform a POST request.
	 *
	 * @param path URI to access
	 * @return the JSON-decoded response
	 *
     * @throws AthenahealthException If there is an error making the call.
     *                               API-level errors are reported in the return-value.
	 */
	public Object POST(String path) throws AthenahealthException {
		return POST(path, null, null);
	}

	/**
	 * Perform a POST request.
	 *
	 * @param path       URI to access
	 * @param parameters the request parameters
	 * @return the JSON-decoded response
	 *
     * @throws AthenahealthException If there is an error making the call.
     *                               API-level errors are reported in the return-value.
	 */
	public Object POST(String path, Map<String, String> parameters) throws AthenahealthException {
		return POST(path, parameters, null);
	}

	/**
	 * Perform a POST request.
	 *
	 * @param path       URI to access
	 * @param parameters the request parameters
	 * @param headers    the request headers
	 * @return the JSON-decoded response
	 *
     * @throws AthenahealthException If there is an error making the call.
     *                               API-level errors are reported in the return-value.
	 */
	public Object POST(String path, Map<String, String> parameters, Map<String, String> headers) throws AthenahealthException {
		return call("POST", path, parameters, headers, false);
	}


	/**
	 * Perform a PUT request.
	 *
	 * @param path URI to access
	 * @return the JSON-decoded response
	 *
     * @throws AthenahealthException If there is an error making the call.
     *                               API-level errors are reported in the return-value.
	 */
	public Object PUT(String path) throws AthenahealthException {
		return PUT(path, null, null);
	}

	/**
	 * Perform a PUT request.
	 *
	 * @param path       URI to access
	 * @param parameters the request parameters
	 * @return the JSON-decoded response
	 *
     * @throws AthenahealthException If there is an error making the call.
     *                               API-level errors are reported in the return-value.
	 */
	public Object PUT(String path, Map<String, String> parameters) throws AthenahealthException {
		return PUT(path, parameters, null);
	}

	/**
	 * Perform a PUT request.
	 *
	 * @param path       URI to access
	 * @param parameters the request parameters
	 * @param headers    the request headers
	 * @return the JSON-decoded response
	 *
     * @throws AthenahealthException If there is an error making the call.
     *                               API-level errors are reported in the return-value.
	 */
	public Object PUT(String path, Map<String, String> parameters, Map<String, String> headers) throws AthenahealthException {
		return call("PUT", path, parameters, headers, false);
	}


	/**
	 * Perform a DELETE request.
	 *
	 * @param path URI to access
	 * @return the JSON-decoded response
	 *
     * @throws AthenahealthException If there is an error making the call.
     *                               API-level errors are reported in the return-value.
	 */
	public Object DELETE(String path) throws AthenahealthException {
		return DELETE(path, null, null);
	}

	/**
	 * Perform a DELETE request.
	 *
	 * @param path       URI to access
	 * @param parameters the request parameters
	 * @return the JSON-decoded response
	 *
     * @throws AthenahealthException If there is an error making the call.
     *                               API-level errors are reported in the return-value.
	 */
	public Object DELETE(String path, Map<String, String> parameters) throws AthenahealthException {
		return DELETE(path, parameters, null);
	}

	/**
	 * Perform a DELETE request.
	 *
	 * @param path       URI to access
	 * @param parameters the request parameters
	 * @param headers    the request headers
	 * @return the JSON-decoded response
	 *
     * @throws AthenahealthException If there is an error making the call.
     *                               API-level errors are reported in the return-value.
	 */
	public Object DELETE(String path, Map<String, String> parameters, Map<String, String> headers) throws AthenahealthException {
		String query = "";
		if (parameters != null) {
			query = "?" + encodeUrl(parameters);
		}
		return call("DELETE", path + query, null, headers, false);
	}

	/**
	 * Returns the current access token
	 *
	 * @return the access token
	 */
	public String getToken() {
		return token;
	}

	/**
	 * Set the practice ID to use for requests.
	 *
	 * @param practiceId the new practiceId
	 */
	public void setPracticeID(String practiceId) {
		this.practiceId = practiceId;
	}

	/**
	 * Returns the practice ID currently in use.
	 *
	 * @return the practice ID
	 */
	public String getPracticeID() {
		return this.practiceId;
	}
}
