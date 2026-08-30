package com.hospital.hms.module.billing.dto.response;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public record BillResponse(
        Integer billId,
        Integer patientId,
        String patientName,
        Integer appointmentId,
        LocalDateTime billDate,
        BigDecimal subtotal,
        BigDecimal discount,
        BigDecimal tax,
        BigDecimal totalAmount,
        BigDecimal paidAmount,
        BigDecimal balanceAmount,
        String status,
        Integer rowVersion,
        BigDecimal insuranceCoveredAmount,
        List<BillItemResponse> items,
        List<PaymentResponse> payments) {
}
