package com.hospital.hms.module.laboratory.repository.view;

import java.time.LocalDateTime;

/** Projection over vw_pending_lab_work. */
public interface PendingLabWorkView {

    Integer getOrderId();

    Integer getPatientId();

    Integer getDoctorId();

    Integer getAppointmentId();

    String getTestName();

    String getTestCategory();

    String getPriority();

    LocalDateTime getOrderDate();

    String getStatus();

    Long getHoursWaiting();
}
