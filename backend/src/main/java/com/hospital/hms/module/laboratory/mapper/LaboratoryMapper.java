package com.hospital.hms.module.laboratory.mapper;

import com.hospital.hms.module.laboratory.dto.response.LabOrderResponse;
import com.hospital.hms.module.laboratory.dto.response.LabResultResponse;
import com.hospital.hms.module.laboratory.dto.response.LabTestResponse;
import com.hospital.hms.module.laboratory.entity.LabOrder;
import com.hospital.hms.module.laboratory.entity.LabResult;
import com.hospital.hms.module.laboratory.entity.LabTest;
import org.springframework.stereotype.Component;

@Component
public class LaboratoryMapper {

    public LabTestResponse toTestResponse(LabTest t) {
        return new LabTestResponse(
                t.getTestId(),
                t.getTestName(),
                t.getTestCategory(),
                t.getDescription(),
                t.getNormalRange(),
                t.getUnit(),
                t.getPrice(),
                t.getIsActive());
    }

    public LabResultResponse toResultResponse(LabResult r) {
        if (r == null) {
            return null;
        }
        return new LabResultResponse(
                r.getResultId(),
                r.getOrderId(),
                r.getResultValue(),
                r.getResultDate(),
                r.getPerformedBy(),
                r.getRemarks(),
                r.getIsAbnormal());
    }

    public LabOrderResponse toOrderResponse(LabOrder o, LabTest test,
                                            String patientName, String doctorName,
                                            LabResult result) {
        return new LabOrderResponse(
                o.getOrderId(),
                o.getAppointmentId(),
                o.getPatientId(),
                patientName,
                o.getDoctorId(),
                doctorName,
                o.getTestId(),
                test == null ? null : test.getTestName(),
                test == null ? null : test.getNormalRange(),
                test == null ? null : test.getUnit(),
                o.getOrderDate(),
                o.getPriority() == null ? null : o.getPriority().name(),
                o.getStatus() == null ? null : o.getStatus().dbValue(),
                o.getNotes(),
                toResultResponse(result));
    }
}
