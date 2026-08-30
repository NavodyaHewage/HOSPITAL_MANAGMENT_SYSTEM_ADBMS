package com.hospital.hms.module.doctor.mapper;

import com.hospital.hms.module.doctor.dto.response.DoctorResponse;
import com.hospital.hms.module.doctor.entity.Doctor;
import org.springframework.stereotype.Component;

@Component
public class DoctorMapper {

    public DoctorResponse toResponse(Doctor d, String departmentName) {
        return new DoctorResponse(
                d.getDoctorId(),
                d.getDepartmentId(),
                departmentName,
                d.getFirstName() + " " + d.getLastName(),
                d.getSpecialization(),
                d.getQualification(),
                d.getLicenseNumber(),
                d.getPhone(),
                d.getEmail(),
                d.getConsultationFee(),
                d.getIsActive());
    }
}
