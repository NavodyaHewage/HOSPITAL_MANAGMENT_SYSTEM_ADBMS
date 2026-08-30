package com.hospital.hms.common.exception;

/** Bad credentials, expired/invalid token, or a deactivated account. */
public class UnauthorizedException extends RuntimeException {

    public UnauthorizedException(String message) {
        super(message);
    }
}
