package com.hospital.hms.module.billing.repository.view;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** Projection over vw_patient_billing_summary. Column names must match exactly. */
public interface PatientBillingSummaryView {

    Integer getPatientId();

    Long getTotalBills();

    BigDecimal getTotalBilled();

    BigDecimal getTotalPaid();

    BigDecimal getTotalBalance();

    LocalDateTime getLastBillDate();
}
