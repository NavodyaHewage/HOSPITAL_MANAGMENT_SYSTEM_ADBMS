package com.hospital.hms.module.prescription.repository.view;

import java.time.LocalDateTime;

/** Projection over vw_active_prescriptions (one row per prescribed medicine). */
public interface ActivePrescriptionView {

    Integer getPrescriptionId();

    Integer getPatientId();

    Integer getDoctorId();

    LocalDateTime getPrescriptionDate();

    Integer getItemId();

    Integer getMedicineId();

    String getMedicineName();

    String getDosage();

    String getFrequency();

    Integer getDurationDays();

    Integer getQuantity();
}
