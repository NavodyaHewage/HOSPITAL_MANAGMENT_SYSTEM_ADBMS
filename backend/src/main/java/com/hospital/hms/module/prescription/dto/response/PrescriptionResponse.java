package com.hospital.hms.module.prescription.dto.response;

import java.time.LocalDateTime;
import java.util.List;

public record PrescriptionResponse(
        Integer prescriptionId,
        Integer consultationId,
        Integer appointmentId,
        Integer patientId,
        String patientName,
        Integer doctorId,
        String doctorName,
        LocalDateTime prescriptionDate,
        String status,
        String notes,
        Integer distinctMedicines,
        Integer totalUnits,
        List<PrescriptionItemResponse> items) {
}
