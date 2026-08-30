package com.hospital.hms.security.rbac;

/**
 * Mirrors the permission_name column seeded in the permissions table.
 *
 * <p>These strings are NOT free-form. A JWT carries the permission names read
 * out of user_roles -> role_permissions -> permissions, and {@code @PreAuthorize}
 * compares against them literally, so any constant that does not exist in the
 * table can never be granted and silently denies every caller. Keep this class
 * and the INSERT INTO permissions block in database/seed/02_seed_data.sql in
 * lockstep - {@code PermissionsIntegrityTest} fails the build if they drift.
 */
public final class Permissions {

    /* --- Patient ------------------------------------------------------- */
    public static final String PATIENT_READ = "PATIENT_READ";
    public static final String PATIENT_WRITE = "PATIENT_WRITE";

    /* --- Appointment --------------------------------------------------- */
    public static final String APPOINTMENT_BOOK = "APPOINTMENT_BOOK";

    /* --- Clinical ------------------------------------------------------ */
    public static final String CONSULT_WRITE = "CONSULT_WRITE";
    public static final String PRESCRIBE = "PRESCRIBE";
    public static final String LAB_ORDER = "LAB_ORDER";
    public static final String LAB_RESULT_WRITE = "LAB_RESULT_WRITE";

    /* --- Billing ------------------------------------------------------- */
    public static final String BILL_CREATE = "BILL_CREATE";
    public static final String PAYMENT_RECORD = "PAYMENT_RECORD";

    /* --- Inventory ----------------------------------------------------- */
    public static final String STOCK_RECEIVE = "STOCK_RECEIVE";
    public static final String STOCK_DISPENSE = "STOCK_DISPENSE";

    /* --- Security ------------------------------------------------------ */
    public static final String AUDIT_READ = "AUDIT_READ";
    public static final String USER_MANAGE = "USER_MANAGE";

    /** Every permission the schema knows about, in seed order. */
    public static final java.util.List<String> ALL = java.util.List.of(
            PATIENT_READ, PATIENT_WRITE, APPOINTMENT_BOOK, CONSULT_WRITE, PRESCRIBE,
            LAB_ORDER, LAB_RESULT_WRITE, BILL_CREATE, PAYMENT_RECORD,
            STOCK_RECEIVE, STOCK_DISPENSE, AUDIT_READ, USER_MANAGE);

    private Permissions() {
    }
}
