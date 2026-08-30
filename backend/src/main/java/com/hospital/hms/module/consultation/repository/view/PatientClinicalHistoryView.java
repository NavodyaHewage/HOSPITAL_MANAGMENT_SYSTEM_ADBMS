package com.hospital.hms.module.consultation.repository.view;

import java.time.LocalDate;
import java.time.LocalDateTime;

/** Projection over vw_patient_clinical_history. */
public interface PatientClinicalHistoryView {

    Integer getPatientId();

    Integer getConsultationId();

    Integer getAppointmentId();

    LocalDateTime getConsultationDate();

    String getChiefComplaint();

    String getDiagnosis();

    LocalDate getFollowUpDate();

    Integer getDoctorId();

    String getDoctorName();
}
