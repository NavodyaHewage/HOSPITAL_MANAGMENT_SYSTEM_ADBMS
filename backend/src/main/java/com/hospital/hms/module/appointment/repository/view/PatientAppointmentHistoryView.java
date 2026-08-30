package com.hospital.hms.module.appointment.repository.view;

import java.time.LocalDate;
import java.time.LocalTime;

/** Projection over vw_patient_appointment_history. */
public interface PatientAppointmentHistoryView {

    Integer getPatientId();

    String getPatientName();

    Integer getAppointmentId();

    LocalDate getAppointmentDate();

    LocalTime getAppointmentTime();

    String getDoctorName();

    String getStatus();

    String getReason();
}
