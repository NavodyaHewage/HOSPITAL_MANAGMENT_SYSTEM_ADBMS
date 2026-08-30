package com.hospital.hms.module.billing.repository;

import com.hospital.hms.module.billing.entity.Payment;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, Integer> {

    /** Uses idx_payments_bill_date. */
    List<Payment> findByBillIdOrderByPaymentDate(Integer billId);

    Page<Payment> findAllByOrderByPaymentDateDesc(Pageable pageable);
}
