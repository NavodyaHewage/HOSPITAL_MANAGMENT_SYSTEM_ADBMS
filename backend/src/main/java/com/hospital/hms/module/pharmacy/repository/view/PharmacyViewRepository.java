package com.hospital.hms.module.pharmacy.repository.view;

import com.hospital.hms.module.pharmacy.entity.Medicine;
import java.util.List;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

public interface PharmacyViewRepository extends Repository<Medicine, Integer> {

    @Query(value = """
            SELECT medicine_id, medicine_name, category, reorder_level,
                   total_available, stock_status
            FROM vw_current_medicine_stock
            WHERE (:onlyReorder = false OR stock_status = 'REORDER')
            ORDER BY stock_status DESC, medicine_name
            """, nativeQuery = true)
    List<CurrentMedicineStockView> findCurrentStock(@Param("onlyReorder") boolean onlyReorder);

    @Query(value = """
            SELECT batch_id, medicine_id, medicine_name, batch_number, quantity_available,
                   expiry_date, days_to_expiry, expiry_status
            FROM vw_expiring_batches
            ORDER BY expiry_date
            """, nativeQuery = true)
    List<ExpiringBatchView> findExpiringBatches();

    @Query(value = """
            SELECT dispensation_id, patient_id, prescription_id, dispensed_date,
                   dispensed_by, total_items, status, doctor_id
            FROM vw_dispensing_history
            WHERE (:patientId IS NULL OR patient_id = :patientId)
            ORDER BY dispensed_date DESC
            LIMIT :limit
            """, nativeQuery = true)
    List<DispensingHistoryView> findDispensingHistory(@Param("patientId") Integer patientId,
                                                      @Param("limit") int limit);
}
