package com.hospital.hms.module.patient.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record PatientRequest(
        Integer patientId,

        @NotBlank @Size(max = 50) String firstName,
        @NotBlank @Size(max = 50) String lastName,
        @NotNull @Past LocalDate dateOfBirth,
        @NotBlank @Pattern(regexp = "Male|Female|Other") String gender,
        @Size(max = 5) String bloodGroup,
        @NotBlank @Size(max = 20) String phone,
        @Email @Size(max = 100) String email,
        @Size(max = 255) String address,
        @Size(max = 100) String emergencyContactName,
        @Size(max = 20) String emergencyContactPhone,
        @Size(max = 30) String nationalId) {
}
