package com.hospital.hms.module.prescription.service;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.prescription.dto.request.PrescriptionRequest;
import com.hospital.hms.module.prescription.dto.response.PrescriptionResponse;
import com.hospital.hms.module.prescription.repository.view.ActivePrescriptionView;
import java.util.List;

public interface PrescriptionService {

    PrescriptionResponse create(PrescriptionRequest request);

    PrescriptionResponse getById(Integer prescriptionId);

    PageResponse<PrescriptionResponse> listByPatient(Integer patientId, int page, int size);

    PageResponse<PrescriptionResponse> listByStatus(String status, int page, int size);

    List<ActivePrescriptionView> activePrescriptions(Integer patientId);

    PrescriptionResponse updateStatus(Integer prescriptionId, String status);
}
