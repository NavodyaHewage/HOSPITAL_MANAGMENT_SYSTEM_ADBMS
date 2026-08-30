package com.hospital.hms.module.pharmacy.repository.procedure;

import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import com.hospital.hms.module.pharmacy.dto.request.DispenseRequest;
import com.hospital.hms.module.pharmacy.dto.request.ReceiveStockRequest;
import com.hospital.hms.module.pharmacy.dto.request.StockAdjustmentRequest;
import java.math.BigDecimal;
import java.sql.Date;
import java.util.HashMap;
import java.util.Map;
import org.springframework.stereotype.Repository;

/**
 * Wraps the three inventory procedures and the three stock functions.
 *
 * <p>Nothing in this module ever writes inventory_batches.quantity_available
 * directly - that column belongs to trg_stock_tx_ai_apply. Every movement is
 * expressed as a stock_transactions row and the trigger derives the balance, so
 * the batch and its ledger cannot drift apart.
 */
@Repository
public class PharmacyProcedureRepository {

    private static final String SP_RECEIVE = "sp_receive_medicine_stock";
    private static final String SP_DISPENSE = "sp_dispense_medicine";
    private static final String SP_ADJUST = "sp_record_stock_adjustment";

    private static final String FN_AVAILABLE_STOCK = "fn_calculate_available_stock";
    private static final String FN_NEEDS_REORDER = "fn_check_reorder_requirement";
    private static final String FN_STOCK_VALUE = "fn_calculate_stock_value";

    private final StoredProcedureExecutor executor;

    public PharmacyProcedureRepository(StoredProcedureExecutor executor) {
        this.executor = executor;
    }

    /** Creates the batch and its opening 'Receive' movement in one transaction. */
    public Integer receiveStock(ReceiveStockRequest request, String performedBy) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_batch_id", null);
        params.put("p_medicine_id", request.medicineId());
        params.put("p_batch_number", request.batchNumber());
        params.put("p_quantity", request.quantity());
        params.put("p_manufacture", request.manufactureDate() == null
                ? null : Date.valueOf(request.manufactureDate()));
        params.put("p_expiry", Date.valueOf(request.expiryDate()));
        params.put("p_supplier", request.supplierName());
        params.put("p_purchase_price", request.purchasePrice());
        params.put("p_performed_by", performedBy);

        Map<String, Object> out = executor.call(SP_RECEIVE, params);
        Object id = out.get("p_batch_id");
        return id == null ? null : ((Number) id).intValue();
    }

    /**
     * FIFO/FEFO dispense. The procedure walks batches in expiry order, X-locking
     * one batch row at a time, so two pharmacists dispensing the same drug queue
     * up instead of both reading the same quantity_available. Insufficient stock
     * rolls the whole thing back, including the dispensation header.
     */
    public Integer dispense(DispenseRequest request, String dispensedBy) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_dispensation_id", null);
        params.put("p_prescription_id", request.prescriptionId());
        params.put("p_medicine_id", request.medicineId());
        params.put("p_quantity", request.quantity());
        params.put("p_dispensed_by", dispensedBy);

        Map<String, Object> out = executor.call(SP_DISPENSE, params);
        Object id = out.get("p_dispensation_id");
        return id == null ? null : ((Number) id).intValue();
    }

    /** direction is ADD or REMOVE; quantity is always positive. */
    public void adjustStock(StockAdjustmentRequest request, String performedBy) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_batch_id", request.batchId());
        params.put("p_quantity", request.quantity());
        params.put("p_direction", request.direction());
        params.put("p_performed_by", performedBy);
        params.put("p_notes", request.notes());

        executor.call(SP_ADJUST, params);
    }

    /** fn_calculate_available_stock - excludes expired batches. */
    public int availableStock(Integer medicineId) {
        Integer stock = executor.callFunction(FN_AVAILABLE_STOCK, Integer.class, medicineId);
        return stock == null ? 0 : stock;
    }

    /** fn_check_reorder_requirement. */
    public boolean needsReorder(Integer medicineId) {
        Boolean needs = executor.callFunction(FN_NEEDS_REORDER, Boolean.class, medicineId);
        return Boolean.TRUE.equals(needs);
    }

    /** fn_calculate_stock_value - unexpired stock at purchase price. */
    public BigDecimal stockValue(Integer medicineId) {
        BigDecimal value = executor.callFunction(FN_STOCK_VALUE, BigDecimal.class, medicineId);
        return value == null ? BigDecimal.ZERO : value;
    }
}
