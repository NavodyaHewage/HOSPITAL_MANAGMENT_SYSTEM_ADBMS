package com.hospital.hms.module.appointment.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.appointment.dto.request.BookAppointmentRequest;
import com.hospital.hms.module.appointment.dto.request.UpdateAppointmentStatusRequest;
import com.hospital.hms.module.appointment.dto.response.AppointmentResponse;
import com.hospital.hms.module.appointment.repository.view.DoctorDailyScheduleView;
import com.hospital.hms.module.appointment.repository.view.PatientAppointmentHistoryView;
import com.hospital.hms.module.appointment.repository.view.UpcomingAppointmentView;
import com.hospital.hms.module.appointment.service.AppointmentService;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/appointments")
public class AppointmentController {

    private final AppointmentService appointmentService;

    public AppointmentController(AppointmentService appointmentService) {
        this.appointmentService = appointmentService;
    }

    /**
     * Book (null appointmentId) or reschedule (populated appointmentId).
     * A slot already taken comes back as HTTP 409 carrying the message raised
     * by sp_book_or_reschedule_appointment.
     */
    @PostMapping
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).APPOINTMENT_BOOK)")
    public ApiResponse<AppointmentResponse> bookOrReschedule(
            @Valid @RequestBody BookAppointmentRequest request) {
        return ApiResponse.ok("Appointment saved", appointmentService.bookOrReschedule(request));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<AppointmentResponse> getById(@PathVariable Integer id) {
        return ApiResponse.ok(appointmentService.getById(id));
    }

    @GetMapping
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PageResponse<AppointmentResponse>> search(
            @RequestParam(required = false) Integer doctorId,
            @RequestParam(required = false) Integer patientId,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(appointmentService.search(doctorId, patientId, status,
                fromDate, toDate, page, size));
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).APPOINTMENT_BOOK)")
    public ApiResponse<AppointmentResponse> updateStatus(
            @PathVariable Integer id,
            @Valid @RequestBody UpdateAppointmentStatusRequest request) {
        return ApiResponse.ok("Status updated", appointmentService.updateStatus(id, request));
    }

    /** Cancels rather than deletes - the row is clinical history. */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).APPOINTMENT_BOOK)")
    public ApiResponse<AppointmentResponse> cancel(@PathVariable Integer id) {
        return ApiResponse.ok("Appointment cancelled", appointmentService.cancel(id));
    }

    @GetMapping("/upcoming")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<List<UpcomingAppointmentView>> upcoming(
            @RequestParam(required = false) Integer doctorId,
            @RequestParam(defaultValue = "50") int limit) {
        return ApiResponse.ok(appointmentService.upcoming(doctorId, limit));
    }

    @GetMapping("/schedule")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<List<DoctorDailyScheduleView>> doctorSchedule(
            @RequestParam Integer doctorId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return ApiResponse.ok(appointmentService.doctorSchedule(doctorId, date));
    }

    @GetMapping("/history/{patientId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<List<PatientAppointmentHistoryView>> patientHistory(
            @PathVariable Integer patientId) {
        return ApiResponse.ok(appointmentService.patientHistory(patientId));
    }

    /** Backed by fn_count_patient_appointments; omit status to count them all. */
    @GetMapping("/count/{patientId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<Map<String, Integer>> countForPatient(
            @PathVariable Integer patientId,
            @RequestParam(required = false) String status) {
        return ApiResponse.ok(Map.of("count",
                appointmentService.countForPatient(patientId, status)));
    }
}
