package com.hospital.hms.module.patient.repository.view;

import java.math.BigDecimal;

/**
 * Projection over vw_patient_billing_summary. Views are mapped as read-only
 * projections instead of entities so JPA never tries to write to them.
 */
public interface PatientBillingSummaryView {

    Integer getPatientId();

    String getPatientName();

    Long getTotalBills();

    BigDecimal getTotalBilled();

    BigDecimal getTotalPaid();

    BigDecimal getOutstanding();
}
