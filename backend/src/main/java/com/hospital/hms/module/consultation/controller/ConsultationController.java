package com.hospital.hms.module.consultation.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.consultation.dto.request.ConsultationRequest;
import com.hospital.hms.module.consultation.dto.request.UpdateConsultationRequest;
import com.hospital.hms.module.consultation.dto.response.ConsultationResponse;
import com.hospital.hms.module.consultation.repository.view.PatientClinicalHistoryView;
import com.hospital.hms.module.consultation.service.ConsultationService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/consultations")
public class ConsultationController {

    private final ConsultationService consultationService;

    public ConsultationController(ConsultationService consultationService) {
        this.consultationService = consultationService;
    }

    /** Also flips the appointment to Completed - see sp_create_consultation. */
    @PostMapping
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).CONSULT_WRITE)")
    public ApiResponse<ConsultationResponse> create(@Valid @RequestBody ConsultationRequest request) {
        return ApiResponse.ok("Consultation recorded", consultationService.create(request));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<ConsultationResponse> getById(@PathVariable Integer id) {
        return ApiResponse.ok(consultationService.getById(id));
    }

    @GetMapping("/by-appointment/{appointmentId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<ConsultationResponse> getByAppointment(@PathVariable Integer appointmentId) {
        return ApiResponse.ok(consultationService.getByAppointmentId(appointmentId));
    }

    @GetMapping("/by-patient/{patientId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PageResponse<ConsultationResponse>> listByPatient(
            @PathVariable Integer patientId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(consultationService.listByPatient(patientId, page, size));
    }

    @GetMapping("/by-doctor/{doctorId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PageResponse<ConsultationResponse>> listByDoctor(
            @PathVariable Integer doctorId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(consultationService.listByDoctor(doctorId, page, size));
    }

    @GetMapping("/history/{patientId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<List<PatientClinicalHistoryView>> clinicalHistory(
            @PathVariable Integer patientId) {
        return ApiResponse.ok(consultationService.clinicalHistory(patientId));
    }

    /** Every change here is captured in audit_logs by trg_consultations_au_audit. */
    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).CONSULT_WRITE)")
    public ApiResponse<ConsultationResponse> update(@PathVariable Integer id,
                                                    @Valid @RequestBody UpdateConsultationRequest request) {
        return ApiResponse.ok("Consultation updated", consultationService.updateNotes(
                id, request.diagnosis(), request.treatmentPlan(), request.notes()));
    }
}
