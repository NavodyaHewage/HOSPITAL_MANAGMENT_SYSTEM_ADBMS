package com.hospital.hms.module.consultation.service;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.consultation.dto.request.ConsultationRequest;
import com.hospital.hms.module.consultation.dto.response.ConsultationResponse;
import com.hospital.hms.module.consultation.repository.view.PatientClinicalHistoryView;
import java.util.List;

public interface ConsultationService {

    ConsultationResponse create(ConsultationRequest request);

    ConsultationResponse getById(Integer consultationId);

    ConsultationResponse getByAppointmentId(Integer appointmentId);

    PageResponse<ConsultationResponse> listByPatient(Integer patientId, int page, int size);

    PageResponse<ConsultationResponse> listByDoctor(Integer doctorId, int page, int size);

    List<PatientClinicalHistoryView> clinicalHistory(Integer patientId);

    ConsultationResponse updateNotes(Integer consultationId, String diagnosis,
                                     String treatmentPlan, String notes);
}
