package com.athenahealth.api;

/**
 * Exception type indicating that AthenaNET API is unavailable because the
 * server has returned a 503 response.
 */
public class UnavailableException
    extends CommunicationException {
    private static final long serialVersionUID = 3791317316140344550L;

    /**
     * Creates a new UnavailableException with the specified detail message.
     *
     * @param message An explanation for the error.
     */
    public UnavailableException(String message) {
        super(message);
    }

    /**
     * Creates a new UnavailableException with the specified detail message
     * and root cause.
     *
     * @param message An explanation for the error.
     * @param cause The root cause of the error.
     */
    public UnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}
