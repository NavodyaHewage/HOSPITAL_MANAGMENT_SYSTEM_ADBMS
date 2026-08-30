package com.hospital.hms.module.pharmacy.dto.response;

import java.time.LocalDateTime;

public record DispensationResponse(
        Integer dispensationId,
        Integer prescriptionId,
        Integer patientId,
        String patientName,
        LocalDateTime dispensedDate,
        String dispensedBy,
        Integer totalItems,
        String status,
        String notes) {
}
