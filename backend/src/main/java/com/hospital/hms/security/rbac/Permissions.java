package com.hospital.hms.security.rbac;

/** Mirrors the permission_name column seeded in the permissions table. */
public final class Permissions {

    public static final String PATIENT_READ = "PATIENT_READ";
    public static final String PATIENT_WRITE = "PATIENT_WRITE";
    public static final String APPOINTMENT_BOOK = "APPOINTMENT_BOOK";
    public static final String CONSULTATION_WRITE = "CONSULTATION_WRITE";
    public static final String PRESCRIPTION_WRITE = "PRESCRIPTION_WRITE";
    public static final String LAB_ORDER = "LAB_ORDER";
    public static final String LAB_RESULT_WRITE = "LAB_RESULT_WRITE";
    public static final String PHARMACY_DISPENSE = "PHARMACY_DISPENSE";
    public static final String INVENTORY_MANAGE = "INVENTORY_MANAGE";
    public static final String BILLING_WRITE = "BILLING_WRITE";
    public static final String PAYMENT_RECORD = "PAYMENT_RECORD";
    public static final String USER_MANAGE = "USER_MANAGE";
    public static final String AUDIT_READ = "AUDIT_READ";
    public static final String REPORT_VIEW = "REPORT_VIEW";

    private Permissions() {
    }
}
