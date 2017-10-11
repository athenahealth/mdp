package com.athenahealth.api;

/**
 * Exception type indicating that an AthenaNET API call failed due to a
 * transient communication error.
 */
public class CommunicationException
    extends AthenahealthException {
    private static final long serialVersionUID = -3985017534362998890L;

    /**
     * Creates a new CommunicationException with the specified detail message.
     *
     * @param message An explanation for the error.
     */
    public CommunicationException(String message) {
        super(message);
    }

    /**
     * Creates a new UnavailableException with the specified detail message
     * and root cause.
     *
     * @param message An explanation for the error.
     * @param cause The root cause of the error.
     */
    public CommunicationException(String message, Throwable cause) {
        super(message, cause);
    }
}
