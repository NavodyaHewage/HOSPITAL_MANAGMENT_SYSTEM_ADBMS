package com.hospital.hms.module.appointment.repository.view;

import java.time.LocalDate;
import java.time.LocalTime;

/** Projection over vw_doctor_daily_schedule. */
public interface DoctorDailyScheduleView {

    Integer getDoctorId();

    String getDoctorName();

    LocalDate getAppointmentDate();

    LocalTime getAppointmentTime();

    String getStatus();

    Integer getPatientId();

    String getPatientName();

    String getReason();
}
