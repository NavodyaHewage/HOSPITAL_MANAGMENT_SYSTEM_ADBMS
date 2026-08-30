package com.hospital.hms.module.prescription.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.prescription.dto.request.PrescriptionRequest;
import com.hospital.hms.module.prescription.dto.response.PrescriptionResponse;
import com.hospital.hms.module.prescription.repository.view.ActivePrescriptionView;
import com.hospital.hms.module.prescription.service.PrescriptionService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Pattern;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/prescriptions")
@Validated
public class PrescriptionController {

    private final PrescriptionService prescriptionService;

    public PrescriptionController(PrescriptionService prescriptionService) {
        this.prescriptionService = prescriptionService;
    }

    @PostMapping
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PRESCRIBE)")
    public ApiResponse<PrescriptionResponse> create(@Valid @RequestBody PrescriptionRequest request) {
        return ApiResponse.ok("Prescription issued", prescriptionService.create(request));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PrescriptionResponse> getById(@PathVariable Integer id) {
        return ApiResponse.ok(prescriptionService.getById(id));
    }

    @GetMapping("/by-patient/{patientId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PageResponse<PrescriptionResponse>> listByPatient(
            @PathVariable Integer patientId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(prescriptionService.listByPatient(patientId, page, size));
    }

    @GetMapping
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PageResponse<PrescriptionResponse>> listByStatus(
            @RequestParam(defaultValue = "Active")
            @Pattern(regexp = "Active|Completed|Cancelled") String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(prescriptionService.listByStatus(status, page, size));
    }

    /** Backed by vw_active_prescriptions - one row per prescribed medicine. */
    @GetMapping("/active")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<List<ActivePrescriptionView>> active(
            @RequestParam(required = false) Integer patientId) {
        return ApiResponse.ok(prescriptionService.activePrescriptions(patientId));
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PRESCRIBE)")
    public ApiResponse<PrescriptionResponse> updateStatus(
            @PathVariable Integer id,
            @RequestParam @Pattern(regexp = "Active|Completed|Cancelled") String status) {
        return ApiResponse.ok("Prescription updated", prescriptionService.updateStatus(id, status));
    }
}
