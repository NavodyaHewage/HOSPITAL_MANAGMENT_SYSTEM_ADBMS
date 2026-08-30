package com.hospital.hms.module.pharmacy.repository.view;

/** Projection over vw_current_medicine_stock. */
public interface CurrentMedicineStockView {

    Integer getMedicineId();

    String getMedicineName();

    String getCategory();

    Integer getReorderLevel();

    Long getTotalAvailable();

    /** 'REORDER' or 'OK', computed by the view. */
    String getStockStatus();
}
