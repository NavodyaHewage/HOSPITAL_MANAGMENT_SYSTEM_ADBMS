package com.hospital.hms.module.pharmacy.repository;

import com.hospital.hms.module.pharmacy.entity.StockTransaction;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface StockTransactionRepository extends JpaRepository<StockTransaction, Integer> {

    /** Uses idx_stock_transactions_batch_date. */
    Page<StockTransaction> findByBatchIdOrderByTransactionDateDesc(Integer batchId, Pageable pageable);

    Page<StockTransaction> findByMedicineIdOrderByTransactionDateDesc(Integer medicineId, Pageable pageable);
}
