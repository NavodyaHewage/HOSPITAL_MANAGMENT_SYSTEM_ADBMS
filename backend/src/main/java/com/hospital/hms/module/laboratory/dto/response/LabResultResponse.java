package com.hospital.hms.module.laboratory.dto.response;

import java.time.LocalDateTime;

public record LabResultResponse(
        Integer resultId,
        Integer orderId,
        String resultValue,
        LocalDateTime resultDate,
        String performedBy,
        String remarks,
        Boolean isAbnormal) {
}
