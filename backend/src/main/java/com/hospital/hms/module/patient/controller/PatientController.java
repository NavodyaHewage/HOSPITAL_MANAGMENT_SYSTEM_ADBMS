package com.hospital.hms.module.patient.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.patient.dto.request.PatientRequest;
import com.hospital.hms.module.patient.dto.response.PatientResponse;
import com.hospital.hms.module.patient.service.PatientService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/patients")
public class PatientController {

    private final PatientService patientService;

    public PatientController(PatientService patientService) {
        this.patientService = patientService;
    }

    @PostMapping
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_WRITE)")
    public ApiResponse<PatientResponse> registerOrUpdate(@Valid @RequestBody PatientRequest request) {
        return ApiResponse.ok("Patient saved", patientService.registerOrUpdate(request));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PatientResponse> getById(@PathVariable Integer id) {
        return ApiResponse.ok(patientService.getById(id));
    }

    @GetMapping
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PageResponse<PatientResponse>> search(
            @RequestParam(required = false) String term,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(patientService.search(term, page, size));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_WRITE)")
    public ApiResponse<Void> deactivate(@PathVariable Integer id) {
        patientService.deactivate(id);
        return ApiResponse.ok("Patient deactivated", null);
    }
}
