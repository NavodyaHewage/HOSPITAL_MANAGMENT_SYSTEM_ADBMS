package com.hospital.hms.module.doctor.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record DoctorRequest(
        @NotNull Integer departmentId,
        @NotBlank @Size(max = 50) String firstName,
        @NotBlank @Size(max = 50) String lastName,
        @Size(max = 100) String specialization,
        @Size(max = 150) String qualification,
        @NotBlank @Size(max = 50) String licenseNumber,
        @Size(max = 20) String phone,
        @Email @Size(max = 100) String email,
        @NotNull @DecimalMin("0.0") BigDecimal consultationFee) {
}
