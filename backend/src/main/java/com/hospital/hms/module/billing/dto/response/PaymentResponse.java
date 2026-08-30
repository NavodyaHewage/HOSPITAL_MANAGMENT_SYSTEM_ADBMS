package com.hospital.hms.module.billing.dto.response;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record PaymentResponse(
        Integer paymentId,
        Integer billId,
        LocalDateTime paymentDate,
        BigDecimal amount,
        String paymentMethod,
        String referenceNumber,
        String receivedBy,
        String notes) {
}
