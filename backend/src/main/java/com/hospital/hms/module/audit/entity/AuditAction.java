package com.hospital.hms.module.audit.entity;

/**
 * Mirrors ENUM('INSERT','UPDATE','DELETE','LOGIN','LOGOUT','LOCK','UNLOCK').
 * LOCK/UNLOCK were added by database/member5_account_lockout.sql, written by
 * trg_users_account_locked_audit whenever users.is_locked flips.
 */
public enum AuditAction {
    INSERT,
    UPDATE,
    DELETE,
    LOGIN,
    LOGOUT,
    LOCK,
    UNLOCK
}
