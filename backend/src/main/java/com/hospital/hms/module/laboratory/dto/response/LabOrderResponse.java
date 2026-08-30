package com.hospital.hms.module.laboratory.dto.response;

import java.time.LocalDateTime;

public record LabOrderResponse(
        Integer orderId,
        Integer appointmentId,
        Integer patientId,
        String patientName,
        Integer doctorId,
        String doctorName,
        Integer testId,
        String testName,
        String normalRange,
        String unit,
        LocalDateTime orderDate,
        String priority,
        String status,
        String notes,
        LabResultResponse result) {
}
