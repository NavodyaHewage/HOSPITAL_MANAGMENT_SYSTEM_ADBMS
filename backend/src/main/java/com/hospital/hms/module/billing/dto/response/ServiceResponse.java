package com.hospital.hms.module.billing.dto.response;

import java.math.BigDecimal;

public record ServiceResponse(
        Integer serviceId,
        String serviceName,
        String serviceCategory,
        String description,
        BigDecimal price,
        Boolean isActive) {
}
