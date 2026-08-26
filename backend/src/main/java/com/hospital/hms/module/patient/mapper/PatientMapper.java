package com.hospital.hms.module.patient.mapper;

import com.hospital.hms.module.patient.dto.response.PatientResponse;
import com.hospital.hms.module.patient.entity.Patient;
import java.time.LocalDate;
import java.time.Period;
import org.springframework.stereotype.Component;

@Component
public class PatientMapper {

    public PatientResponse toResponse(Patient p) {
        return new PatientResponse(
                p.getPatientId(),
                p.getFirstName() + " " + p.getLastName(),
                p.getDateOfBirth(),
                Period.between(p.getDateOfBirth(), LocalDate.now()).getYears(),
                p.getGender().name(),
                p.getBloodGroup(),
                p.getPhone(),
                p.getEmail(),
                p.getAddress(),
                p.getNationalId(),
                p.getRegisteredDate(),
                p.getIsActive());
    }
}
