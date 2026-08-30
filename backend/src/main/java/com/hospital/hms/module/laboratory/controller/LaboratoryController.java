package com.hospital.hms.module.laboratory.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.laboratory.dto.request.LabOrderRequest;
import com.hospital.hms.module.laboratory.dto.request.LabResultRequest;
import com.hospital.hms.module.laboratory.dto.response.LabOrderResponse;
import com.hospital.hms.module.laboratory.dto.response.LabTestResponse;
import com.hospital.hms.module.laboratory.repository.view.PendingLabWorkView;
import com.hospital.hms.module.laboratory.service.LaboratoryService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Pattern;
import java.util.List;
import java.util.Map;
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
@RequestMapping("/lab")
@Validated
public class LaboratoryController {

    private final LaboratoryService laboratoryService;

    public LaboratoryController(LaboratoryService laboratoryService) {
        this.laboratoryService = laboratoryService;
    }

    @GetMapping("/tests")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<List<LabTestResponse>> listTests() {
        return ApiResponse.ok(laboratoryService.listTests());
    }

    /** Optionally carries the result too - see sp_create_lab_order_result_workflow. */
    @PostMapping("/orders")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).LAB_ORDER)")
    public ApiResponse<LabOrderResponse> placeOrder(@Valid @RequestBody LabOrderRequest request) {
        return ApiResponse.ok("Lab order placed", laboratoryService.placeOrder(request));
    }

    @GetMapping("/orders/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<LabOrderResponse> getOrder(@PathVariable Integer id) {
        return ApiResponse.ok(laboratoryService.getOrder(id));
    }

    /** Recording the result is what completes the order (trg_lab_result_ai_close). */
    @PostMapping("/orders/{id}/result")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).LAB_RESULT_WRITE)")
    public ApiResponse<LabOrderResponse> recordResult(@PathVariable Integer id,
                                                      @Valid @RequestBody LabResultRequest request) {
        return ApiResponse.ok("Result recorded", laboratoryService.recordResult(id, request));
    }

    @GetMapping("/orders/by-appointment/{appointmentId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<List<LabOrderResponse>> listByAppointment(@PathVariable Integer appointmentId) {
        return ApiResponse.ok(laboratoryService.listByAppointment(appointmentId));
    }

    @GetMapping("/orders/by-patient/{patientId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PageResponse<LabOrderResponse>> listByPatient(
            @PathVariable Integer patientId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(laboratoryService.listByPatient(patientId, page, size));
    }

    @GetMapping("/orders")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PageResponse<LabOrderResponse>> listByStatus(
            @RequestParam(defaultValue = "Pending")
            @Pattern(regexp = "Pending|In-Progress|Completed|Cancelled") String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(laboratoryService.listByStatus(status, page, size));
    }

    /** The lab worklist, Stat first - backed by vw_pending_lab_work. */
    @GetMapping("/worklist")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).LAB_RESULT_WRITE)")
    public ApiResponse<List<PendingLabWorkView>> worklist(
            @RequestParam(defaultValue = "100") int limit) {
        return ApiResponse.ok(laboratoryService.pendingWorklist(limit));
    }

    /** Backed by fn_find_pending_lab_count (Pending + In-Progress). */
    @GetMapping("/pending-count/{patientId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<Map<String, Integer>> pendingCount(@PathVariable Integer patientId) {
        return ApiResponse.ok(Map.of("pending",
                laboratoryService.pendingCountForPatient(patientId)));
    }

    @PatchMapping("/orders/{id}/status")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).LAB_RESULT_WRITE)")
    public ApiResponse<LabOrderResponse> updateStatus(
            @PathVariable Integer id,
            @RequestParam @Pattern(regexp = "Pending|In-Progress|Cancelled") String status) {
        return ApiResponse.ok("Order updated", laboratoryService.updateStatus(id, status));
    }
}
