package com.hospital.hms.module.doctor.dto.response;

import java.math.BigDecimal;

public record DoctorResponse(
        Integer doctorId,
        Integer departmentId,
        String departmentName,
        String fullName,
        String specialization,
        String qualification,
        String licenseNumber,
        String phone,
        String email,
        BigDecimal consultationFee,
        Boolean isActive) {
}
