package com.hospital.hms.module.billing.repository;

import com.hospital.hms.module.billing.entity.BillItem;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface BillItemRepository extends JpaRepository<BillItem, Integer> {

    /** Uses idx_bill_items_bill_service. */
    List<BillItem> findByBillId(Integer billId);

    List<BillItem> findByBillIdIn(List<Integer> billIds);
}
