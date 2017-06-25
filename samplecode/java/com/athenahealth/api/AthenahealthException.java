package com.athenahealth.api;

/**
 * Base exception class for Athenahealth API.
 */
public class AthenahealthException
    extends Exception
{
    private static final long serialVersionUID = -2169449032691194437L;

    /**
     * Creates a new AthenahealthException with the specified detail message.
     *
     * @param message An explanation for the error.
     */
    public AthenahealthException(String message)
    {
        super(message);
    }

    /**
     * Creates a new AthenahealthException with the specified detail message.
     *
     * @param message An explanation for the error.
     * @param cause The root cause of the error.
     */
    public AthenahealthException(String message, Throwable cause)
    {
        super(message, cause);
    }
}
