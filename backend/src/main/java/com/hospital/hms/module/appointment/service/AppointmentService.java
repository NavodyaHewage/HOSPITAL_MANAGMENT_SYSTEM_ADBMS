package com.hospital.hms.module.appointment.service;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.appointment.dto.request.BookAppointmentRequest;
import com.hospital.hms.module.appointment.dto.request.UpdateAppointmentStatusRequest;
import com.hospital.hms.module.appointment.dto.response.AppointmentResponse;
import com.hospital.hms.module.appointment.repository.view.DoctorDailyScheduleView;
import com.hospital.hms.module.appointment.repository.view.PatientAppointmentHistoryView;
import com.hospital.hms.module.appointment.repository.view.UpcomingAppointmentView;
import java.time.LocalDate;
import java.util.List;

public interface AppointmentService {

    AppointmentResponse bookOrReschedule(BookAppointmentRequest request);

    AppointmentResponse getById(Integer appointmentId);

    PageResponse<AppointmentResponse> search(Integer doctorId, Integer patientId, String status,
                                             LocalDate fromDate, LocalDate toDate,
                                             int page, int size);

    AppointmentResponse updateStatus(Integer appointmentId, UpdateAppointmentStatusRequest request);

    AppointmentResponse cancel(Integer appointmentId);

    List<UpcomingAppointmentView> upcoming(Integer doctorId, int limit);

    List<DoctorDailyScheduleView> doctorSchedule(Integer doctorId, LocalDate date);

    List<PatientAppointmentHistoryView> patientHistory(Integer patientId);

    int countForPatient(Integer patientId, String status);
}
