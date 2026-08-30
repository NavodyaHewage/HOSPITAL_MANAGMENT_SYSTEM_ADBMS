package com.hospital.hms.module.patient.repository.view;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Projection over vw_patient_billing_summary. Views are mapped as read-only
 * projections instead of entities so JPA never tries to write to them.
 *
 * <p>The getters MUST match the view's actual columns:
 * patient_id, total_bills, total_billed, total_paid, total_balance, last_bill_date.
 * An earlier version of this interface declared getPatientName() and
 * getOutstanding(), neither of which the view selects - Spring Data resolves
 * projection getters by column name, so those would have failed at query time.
 */
public interface PatientBillingSummaryView {

    Integer getPatientId();

    Long getTotalBills();

    BigDecimal getTotalBilled();

    BigDecimal getTotalPaid();

    BigDecimal getTotalBalance();

    LocalDateTime getLastBillDate();
}
