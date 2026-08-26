package com.hospital.hms.module.patient.service.impl;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.common.exception.ResourceNotFoundException;
import com.hospital.hms.module.patient.dto.request.PatientRequest;
import com.hospital.hms.module.patient.dto.response.PatientResponse;
import com.hospital.hms.module.patient.mapper.PatientMapper;
import com.hospital.hms.module.patient.repository.PatientRepository;
import com.hospital.hms.module.patient.repository.procedure.PatientProcedureRepository;
import com.hospital.hms.module.patient.service.PatientService;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PatientServiceImpl implements PatientService {

    private final PatientRepository patientRepository;
    private final PatientProcedureRepository patientProcedureRepository;
    private final PatientMapper mapper;

    public PatientServiceImpl(PatientRepository patientRepository,
                              PatientProcedureRepository patientProcedureRepository,
                              PatientMapper mapper) {
        this.patientRepository = patientRepository;
        this.patientProcedureRepository = patientProcedureRepository;
        this.mapper = mapper;
    }

    @Override
    public PatientResponse registerOrUpdate(PatientRequest request) {
        // The procedure runs its own START TRANSACTION / COMMIT, so no @Transactional here.
        Integer id = patientProcedureRepository.registerOrUpdate(request);
        return getById(id);
    }

    @Override
    @Transactional(readOnly = true)
    public PatientResponse getById(Integer patientId) {
        return patientRepository.findById(patientId)
                .map(mapper::toResponse)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", patientId));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PatientResponse> search(String term, int page, int size) {
        var pageable = PageRequest.of(page, size, Sort.by("lastName").ascending());
        var result = patientRepository.search(term == null ? "" : term, pageable)
                .map(mapper::toResponse);
        return new PageResponse<>(result.getContent(), result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }

    @Override
    @Transactional
    public void deactivate(Integer patientId) {
        var patient = patientRepository.findById(patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", patientId));
        patient.setIsActive(false);
        patientRepository.save(patient);
    }
}
