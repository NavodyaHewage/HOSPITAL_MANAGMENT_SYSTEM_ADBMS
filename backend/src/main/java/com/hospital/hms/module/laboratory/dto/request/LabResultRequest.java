package com.hospital.hms.module.laboratory.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record LabResultRequest(
        @NotBlank @Size(max = 255) String resultValue,
        @Size(max = 100) String performedBy,
        String remarks,
        Boolean isAbnormal) {
}
