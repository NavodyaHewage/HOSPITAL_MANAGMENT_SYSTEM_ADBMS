package com.hospital.hms.module.appointment.repository.view;

import java.time.LocalDate;
import java.time.LocalTime;

/** Projection over vw_upcoming_appointments. */
public interface UpcomingAppointmentView {

    Integer getAppointmentId();

    Integer getPatientId();

    String getPatientName();

    Integer getDoctorId();

    String getDoctorName();

    String getDepartmentName();

    LocalDate getAppointmentDate();

    LocalTime getAppointmentTime();

    String getStatus();
}
