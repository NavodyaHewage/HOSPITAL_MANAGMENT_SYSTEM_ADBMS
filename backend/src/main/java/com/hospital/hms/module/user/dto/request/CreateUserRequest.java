package com.hospital.hms.module.user.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record CreateUserRequest(
        @NotBlank @Size(min = 3, max = 50) String username,

        @NotBlank @Size(min = 8, max = 255,
                message = "Password must be at least 8 characters")
        String password,

        @Email @Size(max = 100) String email,
        @NotBlank @Size(max = 100) String fullName,
        @Size(max = 20) String phone,

        @NotBlank
        @Pattern(regexp = "ADMIN|DOCTOR|NURSE|PHARMACIST|CASHIER|LAB_TECH|RECEPTIONIST",
                message = "must be one of the seven seeded roles")
        String roleName) {
}
