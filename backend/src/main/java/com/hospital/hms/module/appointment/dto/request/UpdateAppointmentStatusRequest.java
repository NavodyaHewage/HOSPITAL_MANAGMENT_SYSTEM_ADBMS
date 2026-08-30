package com.hospital.hms.module.appointment.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record UpdateAppointmentStatusRequest(
        @NotBlank
        @Pattern(regexp = "Scheduled|Confirmed|Completed|Cancelled|No-Show",
                message = "must be one of Scheduled, Confirmed, Completed, Cancelled, No-Show")
        String status,

        String notes) {
}
