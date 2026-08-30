package com.hospital.hms.module.billing.dto.response;

import java.math.BigDecimal;

/** The two OUT parameters of sp_process_complete_payment_transaction. */
public record PaymentOutcome(String status, BigDecimal balance) {
}
