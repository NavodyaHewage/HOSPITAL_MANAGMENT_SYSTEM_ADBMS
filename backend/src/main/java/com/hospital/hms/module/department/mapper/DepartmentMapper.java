package com.hospital.hms.module.department.mapper;

import com.hospital.hms.module.department.dto.response.DepartmentResponse;
import com.hospital.hms.module.department.entity.Department;
import org.springframework.stereotype.Component;

@Component
public class DepartmentMapper {

    public DepartmentResponse toResponse(Department d, Long doctorCount) {
        return new DepartmentResponse(
                d.getDepartmentId(),
                d.getDepartmentName(),
                d.getDescription(),
                d.getLocation(),
                d.getContactNumber(),
                d.getIsActive(),
                doctorCount);
    }
}
