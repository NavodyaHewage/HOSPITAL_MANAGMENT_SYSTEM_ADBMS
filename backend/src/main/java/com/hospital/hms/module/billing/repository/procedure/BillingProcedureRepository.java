package com.hospital.hms.module.billing.repository.procedure;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import com.hospital.hms.module.billing.dto.request.BillRequest;
import com.hospital.hms.module.billing.dto.request.PaymentRequest;
import com.hospital.hms.module.billing.dto.response.PaymentOutcome;
import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import org.springframework.stereotype.Repository;

/**
 * Wraps the three billing procedures and the three billing functions.
 *
 * <p>Nothing here writes bills.paid_amount, balance_amount or status - those
 * belong to trg_payments_ai_apply. The procedures insert the payment FACT and
 * let the trigger derive the consequence, which is why an earlier version of
 * this schema double-counted every payment.
 */
@Repository
public class BillingProcedureRepository {

    private static final String SP_CREATE_BILL = "sp_create_bill_with_items";
    private static final String SP_RECORD_PAYMENT = "sp_record_payment";
    private static final String SP_COMPLETE_PAYMENT = "sp_process_complete_payment_transaction";

    private static final String FN_BILL_SUBTOTAL = "fn_calculate_bill_subtotal";
    private static final String FN_BILL_BALANCE = "fn_calculate_bill_balance";
    private static final String FN_INSURANCE_COVER = "fn_calculate_insurance_covered_amount";

    private final StoredProcedureExecutor executor;
    private final ObjectMapper objectMapper;

    public BillingProcedureRepository(StoredProcedureExecutor executor, ObjectMapper objectMapper) {
        this.executor = executor;
        this.objectMapper = objectMapper;
    }

    /**
     * Header and lines in one transaction. Note that only service_id and
     * quantity are sent: the procedure reads the price from the services master,
     * so a client cannot invent its own price.
     */
    public Integer createBillWithItems(BillRequest request) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_bill_id", null);
        params.put("p_patient_id", request.patientId());
        params.put("p_appointment_id", request.appointmentId());
        params.put("p_items_json", toJson(request));
        params.put("p_discount", request.discount());
        params.put("p_tax_rate", request.taxRate());

        Map<String, Object> out = executor.call(SP_CREATE_BILL, params);
        Object id = out.get("p_bill_id");
        return id == null ? null : ((Number) id).intValue();
    }

    /** Thin wrapper - inserts the payment fact and lets the trigger do the rest. */
    public Integer recordPayment(Integer billId, PaymentRequest request, String receivedBy) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_payment_id", null);
        params.put("p_bill_id", billId);
        params.put("p_amount", request.amount());
        params.put("p_method", request.paymentMethod());
        params.put("p_reference", request.referenceNumber());
        params.put("p_received_by", receivedBy);

        Map<String, Object> out = executor.call(SP_RECORD_PAYMENT, params);
        Object id = out.get("p_payment_id");
        return id == null ? null : ((Number) id).intValue();
    }

    /**
     * The full settlement path: X-locks the bill, optionally applies the
     * insurance credit behind a SAVEPOINT (so an invalid policy is undone
     * without losing the cash payment), refuses to overpay, then commits.
     */
    public PaymentOutcome processCompletePayment(Integer billId, PaymentRequest request,
                                                 boolean applyInsurance, String receivedBy) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_bill_id", billId);
        params.put("p_amount", request.amount());
        params.put("p_method", request.paymentMethod());
        params.put("p_reference", request.referenceNumber());
        params.put("p_received_by", receivedBy);
        params.put("p_apply_insurance", applyInsurance);

        Map<String, Object> out = executor.call(SP_COMPLETE_PAYMENT, params);
        return new PaymentOutcome(
                (String) out.get("p_new_status"),
                (BigDecimal) out.get("p_new_balance"));
    }

    public BigDecimal billSubtotal(Integer billId) {
        return orZero(executor.callFunction(FN_BILL_SUBTOTAL, BigDecimal.class, billId));
    }

    public BigDecimal billBalance(Integer billId) {
        return orZero(executor.callFunction(FN_BILL_BALANCE, BigDecimal.class, billId));
    }

    /** Applies only policies that are active AND currently valid. */
    public BigDecimal insuranceCoveredAmount(Integer billId) {
        return orZero(executor.callFunction(FN_INSURANCE_COVER, BigDecimal.class, billId));
    }

    private BigDecimal orZero(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }

    private String toJson(BillRequest request) {
        try {
            return objectMapper.writeValueAsString(request.items());
        } catch (JsonProcessingException ex) {
            throw new IllegalArgumentException("Bill items could not be serialised", ex);
        }
    }
}
