package com.hospital.hms.module.laboratory.dto.response;

import java.math.BigDecimal;

public record LabTestResponse(
        Integer testId,
        String testName,
        String testCategory,
        String description,
        String normalRange,
        String unit,
        BigDecimal price,
        Boolean isActive) {
}
