package com.hospital.hms.common.exception;

/**
 * Raised when a database routine signals SQLSTATE '45000' - the schema enforces
 * rules such as double-booked appointments, negative stock and over-payment,
 * so those messages are surfaced to the client as-is.
 */
public class BusinessRuleException extends RuntimeException {

    public BusinessRuleException(String message) {
        super(message);
    }
}
