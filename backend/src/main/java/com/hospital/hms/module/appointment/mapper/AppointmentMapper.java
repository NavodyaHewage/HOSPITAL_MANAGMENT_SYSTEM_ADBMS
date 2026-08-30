package com.hospital.hms.module.appointment.mapper;

import com.hospital.hms.module.appointment.dto.response.AppointmentResponse;
import com.hospital.hms.module.appointment.entity.Appointment;
import org.springframework.stereotype.Component;

@Component
public class AppointmentMapper {

    public AppointmentResponse toResponse(Appointment a, String patientName, String doctorName) {
        return new AppointmentResponse(
                a.getAppointmentId(),
                a.getPatientId(),
                patientName,
                a.getDoctorId(),
                doctorName,
                a.getAppointmentDate(),
                a.getAppointmentTime(),
                a.getStatus() == null ? null : a.getStatus().dbValue(),
                a.getReason(),
                a.getNotes(),
                a.getActiveSlotKey(),
                a.getCreatedAt());
    }
}
