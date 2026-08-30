package com.hospital.hms.module.department.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record DepartmentRequest(
        @NotBlank @Size(max = 100) String departmentName,
        @Size(max = 500) String description,
        @Size(max = 100) String location,
        @Size(max = 20) String contactNumber) {
}
