package com.athenahealth.api;

/**
 * Exception type indicating that an authentication error occurred.
 */
public class AuthenticationException
    extends AthenahealthException
{
    private static final long serialVersionUID = -2169449032691194437L;

    /**
     * Creates a new AthenahealthException with the specified detail message.
     *
     * @param message An explanation for the error.
     */
    public AuthenticationException(String message)
    {
        super(message);
    }

    /**
     * Creates a new AthenahealthException with the specified detail message.
     *
     * @param message An explanation for the error.
     * @param cause The root cause of the error.
     */
    public AuthenticationException(String message, Throwable rootCause)
    {
        super(message, rootCause);
    }
}
