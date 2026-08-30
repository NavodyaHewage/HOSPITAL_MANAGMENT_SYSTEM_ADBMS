package com.hospital.hms.module.billing.repository.view;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** Projection over vw_payment_history. */
public interface PaymentHistoryView {

    Integer getPaymentId();

    Integer getBillId();

    Integer getPatientId();

    LocalDateTime getPaymentDate();

    BigDecimal getAmount();

    String getPaymentMethod();

    String getReferenceNumber();

    String getReceivedBy();
}
