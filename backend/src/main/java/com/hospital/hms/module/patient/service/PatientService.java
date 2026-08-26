package com.hospital.hms.module.patient.service;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.patient.dto.request.PatientRequest;
import com.hospital.hms.module.patient.dto.response.PatientResponse;

public interface PatientService {

    PatientResponse registerOrUpdate(PatientRequest request);

    PatientResponse getById(Integer patientId);

    PageResponse<PatientResponse> search(String term, int page, int size);

    void deactivate(Integer patientId);
}
