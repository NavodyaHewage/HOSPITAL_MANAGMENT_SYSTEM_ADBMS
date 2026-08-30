package com.hospital.hms.module.pharmacy.repository.view;

import java.time.LocalDate;

/** Projection over vw_expiring_batches. */
public interface ExpiringBatchView {

    Integer getBatchId();

    Integer getMedicineId();

    String getMedicineName();

    String getBatchNumber();

    Integer getQuantityAvailable();

    LocalDate getExpiryDate();

    Long getDaysToExpiry();

    /** 'EXPIRED', 'CRITICAL' or 'WATCH'. */
    String getExpiryStatus();
}
