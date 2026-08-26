package com.hospital.hms.module.patient.dto.response;

import java.time.LocalDate;

public record PatientResponse(
        Integer patientId,
        String fullName,
        LocalDate dateOfBirth,
        Integer age,
        String gender,
        String bloodGroup,
        String phone,
        String email,
        String address,
        String nationalId,
        LocalDate registeredDate,
        Boolean isActive) {
}
