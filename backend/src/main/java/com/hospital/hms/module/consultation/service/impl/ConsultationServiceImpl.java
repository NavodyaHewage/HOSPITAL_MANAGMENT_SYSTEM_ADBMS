package com.hospital.hms.module.consultation.service.impl;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.common.exception.ResourceNotFoundException;
import com.hospital.hms.common.support.NameResolver;
import com.hospital.hms.module.consultation.dto.request.ConsultationRequest;
import com.hospital.hms.module.consultation.dto.response.ConsultationResponse;
import com.hospital.hms.module.consultation.entity.Consultation;
import com.hospital.hms.module.consultation.mapper.ConsultationMapper;
import com.hospital.hms.module.consultation.repository.ConsultationRepository;
import com.hospital.hms.module.consultation.repository.procedure.ConsultationProcedureRepository;
import com.hospital.hms.module.consultation.repository.view.ConsultationViewRepository;
import com.hospital.hms.module.consultation.repository.view.PatientClinicalHistoryView;
import com.hospital.hms.module.consultation.service.ConsultationService;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ConsultationServiceImpl implements ConsultationService {

    private final ConsultationRepository consultationRepository;
    private final ConsultationProcedureRepository procedureRepository;
    private final ConsultationViewRepository viewRepository;
    private final NameResolver names;
    private final ConsultationMapper mapper;

    public ConsultationServiceImpl(ConsultationRepository consultationRepository,
                                   ConsultationProcedureRepository procedureRepository,
                                   ConsultationViewRepository viewRepository,
                                   NameResolver names,
                                   ConsultationMapper mapper) {
        this.consultationRepository = consultationRepository;
        this.procedureRepository = procedureRepository;
        this.viewRepository = viewRepository;
        this.names = names;
        this.mapper = mapper;
    }

    /**
     * No @Transactional - sp_create_consultation manages its own transaction.
     * It also derives patient_id and doctor_id from the appointment rather than
     * trusting the caller, which is why the request carries neither.
     */
    @Override
    public ConsultationResponse create(ConsultationRequest request) {
        Integer id = procedureRepository.create(request);
        return getById(id);
    }

    @Override
    @Transactional(readOnly = true)
    public ConsultationResponse getById(Integer consultationId) {
        return toResponse(consultationRepository.findById(consultationId)
                .orElseThrow(() -> new ResourceNotFoundException("Consultation", consultationId)));
    }

    @Override
    @Transactional(readOnly = true)
    public ConsultationResponse getByAppointmentId(Integer appointmentId) {
        return toResponse(consultationRepository.findByAppointmentId(appointmentId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Consultation for appointment", appointmentId)));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<ConsultationResponse> listByPatient(Integer patientId, int page, int size) {
        return toPage(consultationRepository.findByPatientIdOrderByConsultationDateDesc(
                patientId, PageRequest.of(page, size)));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<ConsultationResponse> listByDoctor(Integer doctorId, int page, int size) {
        return toPage(consultationRepository.findByDoctorIdOrderByConsultationDateDesc(
                doctorId, PageRequest.of(page, size)));
    }

    @Override
    @Transactional(readOnly = true)
    public List<PatientClinicalHistoryView> clinicalHistory(Integer patientId) {
        return viewRepository.findClinicalHistory(patientId);
    }

    /**
     * Editing a diagnosis is a medico-legal event. trg_consultations_au_audit
     * records the before/after into audit_logs automatically, so nothing extra
     * is written here - the audit trail is the database's job, not the API's.
     */
    @Override
    @Transactional
    public ConsultationResponse updateNotes(Integer consultationId, String diagnosis,
                                            String treatmentPlan, String notes) {
        Consultation consultation = consultationRepository.findById(consultationId)
                .orElseThrow(() -> new ResourceNotFoundException("Consultation", consultationId));

        if (diagnosis != null) {
            consultation.setDiagnosis(diagnosis);
        }
        if (treatmentPlan != null) {
            consultation.setTreatmentPlan(treatmentPlan);
        }
        if (notes != null) {
            consultation.setNotes(notes);
        }
        return toResponse(consultationRepository.saveAndFlush(consultation));
    }

    private ConsultationResponse toResponse(Consultation c) {
        return mapper.toResponse(c, names.patientName(c.getPatientId()),
                names.doctorName(c.getDoctorId()));
    }

    private PageResponse<ConsultationResponse> toPage(Page<Consultation> page) {
        Map<Integer, String> patients = names.patientNames(page.getContent(), Consultation::getPatientId);
        Map<Integer, String> doctors = names.doctorNames(page.getContent(), Consultation::getDoctorId);

        var content = page.getContent().stream()
                .map(c -> mapper.toResponse(c, patients.get(c.getPatientId()),
                        doctors.get(c.getDoctorId())))
                .toList();

        return new PageResponse<>(content, page.getNumber(), page.getSize(),
                page.getTotalElements(), page.getTotalPages());
    }
}
