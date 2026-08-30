package com.hospital.hms.module.pharmacy.repository;

import com.hospital.hms.module.pharmacy.entity.InventoryBatch;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface InventoryBatchRepository extends JpaRepository<InventoryBatch, Integer> {

    Optional<InventoryBatch> findByMedicineIdAndBatchNumber(Integer medicineId, String batchNumber);

    /**
     * FIFO/FEFO order - oldest usable expiry first. Uses
     * idx_inventory_batches_medicine_expiry, the same access path
     * sp_dispense_medicine walks.
     */
    @Query("""
            SELECT b FROM InventoryBatch b
            WHERE b.medicineId = :medicineId
              AND b.quantityAvailable > 0
              AND b.expiryDate >= CURRENT_DATE
            ORDER BY b.expiryDate, b.batchId
            """)
    List<InventoryBatch> findUsableBatches(@Param("medicineId") Integer medicineId);

    /** Uses idx_inventory_batches_expiry. */
    List<InventoryBatch> findByExpiryDateLessThanEqualOrderByExpiryDate(LocalDate cutoff);
}
