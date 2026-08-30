package com.hospital.hms.module.consultation.mapper;

import com.hospital.hms.module.consultation.dto.response.ConsultationResponse;
import com.hospital.hms.module.consultation.entity.Consultation;
import org.springframework.stereotype.Component;

@Component
public class ConsultationMapper {

    public ConsultationResponse toResponse(Consultation c, String patientName, String doctorName) {
        return new ConsultationResponse(
                c.getConsultationId(),
                c.getAppointmentId(),
                c.getPatientId(),
                patientName,
                c.getDoctorId(),
                doctorName,
                c.getConsultationDate(),
                c.getChiefComplaint(),
                c.getDiagnosis(),
                c.getSymptoms(),
                c.getTreatmentPlan(),
                c.getNotes(),
                c.getFollowUpDate());
    }
}
