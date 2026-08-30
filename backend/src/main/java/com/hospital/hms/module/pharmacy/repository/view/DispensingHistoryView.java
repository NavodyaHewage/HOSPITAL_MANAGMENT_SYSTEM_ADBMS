package com.hospital.hms.module.pharmacy.repository.view;

import java.time.LocalDateTime;

/** Projection over vw_dispensing_history. */
public interface DispensingHistoryView {

    Integer getDispensationId();

    Integer getPatientId();

    Integer getPrescriptionId();

    LocalDateTime getDispensedDate();

    String getDispensedBy();

    Integer getTotalItems();

    String getStatus();

    Integer getDoctorId();
}
