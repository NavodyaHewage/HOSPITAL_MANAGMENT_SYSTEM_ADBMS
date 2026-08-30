package com.hospital.hms.module.billing.dto.response;

import java.math.BigDecimal;

public record BillItemResponse(
        Integer billItemId,
        Integer serviceId,
        String serviceName,
        String description,
        Integer quantity,
        BigDecimal unitPrice,
        BigDecimal amount) {
}
