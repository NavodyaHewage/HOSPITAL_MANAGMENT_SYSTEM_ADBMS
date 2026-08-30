package com.hospital.hms.module.laboratory.service;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.laboratory.dto.request.LabOrderRequest;
import com.hospital.hms.module.laboratory.dto.request.LabResultRequest;
import com.hospital.hms.module.laboratory.dto.response.LabOrderResponse;
import com.hospital.hms.module.laboratory.dto.response.LabTestResponse;
import com.hospital.hms.module.laboratory.repository.view.PendingLabWorkView;
import java.util.List;

public interface LaboratoryService {

    List<LabTestResponse> listTests();

    LabOrderResponse placeOrder(LabOrderRequest request);

    LabOrderResponse recordResult(Integer orderId, LabResultRequest request);

    LabOrderResponse getOrder(Integer orderId);

    List<LabOrderResponse> listByAppointment(Integer appointmentId);

    PageResponse<LabOrderResponse> listByPatient(Integer patientId, int page, int size);

    PageResponse<LabOrderResponse> listByStatus(String status, int page, int size);

    List<PendingLabWorkView> pendingWorklist(int limit);

    int pendingCountForPatient(Integer patientId);

    LabOrderResponse updateStatus(Integer orderId, String status);
}
