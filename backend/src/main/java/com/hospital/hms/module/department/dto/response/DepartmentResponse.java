package com.hospital.hms.module.department.dto.response;

public record DepartmentResponse(
        Integer departmentId,
        String departmentName,
        String description,
        String location,
        String contactNumber,
        Boolean isActive,
        Long doctorCount) {
}
