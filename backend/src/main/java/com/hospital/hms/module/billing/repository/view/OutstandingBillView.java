package com.hospital.hms.module.billing.repository.view;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** Projection over vw_outstanding_bills. */
public interface OutstandingBillView {

    Integer getBillId();

    Integer getPatientId();

    String getPatientName();

    String getPhone();

    LocalDateTime getBillDate();

    BigDecimal getTotalAmount();

    BigDecimal getPaidAmount();

    BigDecimal getBalanceAmount();

    String getStatus();

    Long getDaysOutstanding();
}
