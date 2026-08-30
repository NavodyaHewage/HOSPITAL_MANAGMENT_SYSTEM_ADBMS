package com.hospital.hms.module.doctor.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.doctor.dto.request.DoctorRequest;
import com.hospital.hms.module.doctor.dto.response.DoctorAvailabilityResponse;
import com.hospital.hms.module.doctor.dto.response.DoctorResponse;
import com.hospital.hms.module.doctor.service.DoctorService;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/doctors")
public class DoctorController {

    private final DoctorService doctorService;

    public DoctorController(DoctorService doctorService) {
        this.doctorService = doctorService;
    }

    @GetMapping
    public ApiResponse<PageResponse<DoctorResponse>> search(
            @RequestParam(required = false) String term,
            @RequestParam(required = false) Integer departmentId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(doctorService.search(term, departmentId, page, size));
    }

    @GetMapping("/{id}")
    public ApiResponse<DoctorResponse> getById(@PathVariable Integer id) {
        return ApiResponse.ok(doctorService.getById(id));
    }

    @GetMapping("/by-department/{departmentId}")
    public ApiResponse<List<DoctorResponse>> listByDepartment(@PathVariable Integer departmentId) {
        return ApiResponse.ok(doctorService.listByDepartment(departmentId));
    }

    /** Backed by sp_search_doctor_availability - who has THIS slot free. */
    @GetMapping("/availability")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).APPOINTMENT_BOOK)")
    public ApiResponse<List<DoctorAvailabilityResponse>> availability(
            @RequestParam(required = false) Integer departmentId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.TIME) LocalTime time) {
        return ApiResponse.ok(doctorService.searchAvailability(departmentId, date, time));
    }

    /**
     * Backed by fn_check_doctor_availability. A convenience check for the UI
     * only - it is not a booking guarantee, because another user can take the
     * slot between this call and the POST that books it.
     */
    @GetMapping("/{id}/slot-free")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).APPOINTMENT_BOOK)")
    public ApiResponse<Map<String, Boolean>> slotFree(
            @PathVariable Integer id,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.TIME) LocalTime time) {
        return ApiResponse.ok(Map.of("available", doctorService.isSlotFree(id, date, time)));
    }

    @PostMapping
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).USER_MANAGE)")
    public ApiResponse<DoctorResponse> create(@Valid @RequestBody DoctorRequest request) {
        return ApiResponse.ok("Doctor created", doctorService.create(request));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).USER_MANAGE)")
    public ApiResponse<DoctorResponse> update(@PathVariable Integer id,
                                              @Valid @RequestBody DoctorRequest request) {
        return ApiResponse.ok("Doctor updated", doctorService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).USER_MANAGE)")
    public ApiResponse<Void> deactivate(@PathVariable Integer id) {
        doctorService.deactivate(id);
        return ApiResponse.ok("Doctor deactivated", null);
    }
}
