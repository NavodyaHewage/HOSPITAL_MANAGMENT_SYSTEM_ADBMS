package com.hospital.hms.module.prescription.repository.procedure;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import com.hospital.hms.module.prescription.dto.request.PrescriptionRequest;
import java.util.HashMap;
import java.util.Map;
import org.springframework.stereotype.Repository;

/**
 * Wraps sp_create_prescription_with_items.
 *
 * <p>The header and every line are written by ONE procedure call so they commit
 * together or not at all. Inserting the header from Java and then looping over
 * the items would leave an orphan header behind the moment one line is rejected
 * by trg_prescription_items_bi_validate.
 *
 * <p>The items travel as a JSON array which the procedure unpacks with
 * JSON_TABLE - see PrescriptionItemRequest for why the field names are
 * snake_case.
 */
@Repository
public class PrescriptionProcedureRepository {

    private static final String SP_CREATE_WITH_ITEMS = "sp_create_prescription_with_items";
    private static final String FN_COUNT_MEDICINES = "fn_count_prescription_medicines";
    private static final String FN_TOTAL_QUANTITY = "fn_calculate_prescription_quantity";

    private final StoredProcedureExecutor executor;
    private final ObjectMapper objectMapper;

    public PrescriptionProcedureRepository(StoredProcedureExecutor executor, ObjectMapper objectMapper) {
        this.executor = executor;
        this.objectMapper = objectMapper;
    }

    public Integer createWithItems(PrescriptionRequest request) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_prescription_id", null);
        params.put("p_consultation_id", request.consultationId());
        params.put("p_items_json", toJson(request));
        params.put("p_notes", request.notes());

        Map<String, Object> out = executor.call(SP_CREATE_WITH_ITEMS, params);
        Object id = out.get("p_prescription_id");
        return id == null ? null : ((Number) id).intValue();
    }

    /** fn_count_prescription_medicines - distinct medicines on the prescription. */
    public int countMedicines(Integer prescriptionId) {
        Integer count = executor.callFunction(FN_COUNT_MEDICINES, Integer.class, prescriptionId);
        return count == null ? 0 : count;
    }

    /** fn_calculate_prescription_quantity - total units across all lines. */
    public int totalQuantity(Integer prescriptionId) {
        Integer total = executor.callFunction(FN_TOTAL_QUANTITY, Integer.class, prescriptionId);
        return total == null ? 0 : total;
    }

    private String toJson(PrescriptionRequest request) {
        try {
            return objectMapper.writeValueAsString(request.items());
        } catch (JsonProcessingException ex) {
            throw new IllegalArgumentException("Prescription items could not be serialised", ex);
        }
    }
}
