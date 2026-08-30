package com.hospital.hms.module.billing.repository.view;

import com.hospital.hms.module.billing.entity.Bill;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

public interface BillingViewRepository extends Repository<Bill, Integer> {

    /** The debtors list, oldest first. */
    @Query(value = """
            SELECT bill_id, patient_id, patient_name, phone, bill_date, total_amount,
                   paid_amount, balance_amount, status, days_outstanding
            FROM vw_outstanding_bills
            ORDER BY days_outstanding DESC
            LIMIT :limit
            """, nativeQuery = true)
    List<OutstandingBillView> findOutstanding(@Param("limit") int limit);

    @Query(value = """
            SELECT payment_id, bill_id, patient_id, payment_date, amount,
                   payment_method, reference_number, received_by
            FROM vw_payment_history
            WHERE (:patientId IS NULL OR patient_id = :patientId)
            ORDER BY payment_date DESC
            LIMIT :limit
            """, nativeQuery = true)
    List<PaymentHistoryView> findPaymentHistory(@Param("patientId") Integer patientId,
                                                @Param("limit") int limit);

    @Query(value = """
            SELECT patient_id, total_bills, total_billed, total_paid,
                   total_balance, last_bill_date
            FROM vw_patient_billing_summary
            WHERE patient_id = :patientId
            """, nativeQuery = true)
    Optional<PatientBillingSummaryView> findBillingSummary(@Param("patientId") Integer patientId);
}
