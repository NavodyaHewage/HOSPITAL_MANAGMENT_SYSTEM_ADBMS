package com.hospital.hms.module.laboratory.repository.procedure;

import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import com.hospital.hms.module.laboratory.dto.request.LabOrderRequest;
import java.util.HashMap;
import java.util.Map;
import org.springframework.stereotype.Repository;

/**
 * Wraps sp_create_lab_order_result_workflow.
 *
 * <p>One call covers both cases: pass a null resultValue to place the order
 * only, or a value to place it and record the result in the same transaction.
 * In the second case trg_lab_result_ai_close flips the order to Completed, so
 * the status is never set from Java.
 */
@Repository
public class LabProcedureRepository {

    private static final String SP_ORDER_RESULT_WORKFLOW = "sp_create_lab_order_result_workflow";
    private static final String FN_PENDING_COUNT = "fn_find_pending_lab_count";

    private final StoredProcedureExecutor executor;

    public LabProcedureRepository(StoredProcedureExecutor executor) {
        this.executor = executor;
    }

    public Integer createOrderWorkflow(LabOrderRequest request) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_order_id", null);
        params.put("p_appointment_id", request.appointmentId());
        params.put("p_test_id", request.testId());
        params.put("p_priority", request.priority());
        params.put("p_result_value", request.resultValue());
        params.put("p_performed_by", request.performedBy());
        params.put("p_is_abnormal", request.isAbnormal());

        Map<String, Object> out = executor.call(SP_ORDER_RESULT_WORKFLOW, params);
        Object id = out.get("p_order_id");
        return id == null ? null : ((Number) id).intValue();
    }

    /** fn_find_pending_lab_count - counts Pending AND In-Progress. */
    public int pendingCountForPatient(Integer patientId) {
        Integer count = executor.callFunction(FN_PENDING_COUNT, Integer.class, patientId);
        return count == null ? 0 : count;
    }
}
