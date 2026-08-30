package com.hospital.hms.module.department.service.impl;

import com.hospital.hms.common.exception.BusinessRuleException;
import com.hospital.hms.common.exception.ResourceNotFoundException;
import com.hospital.hms.module.department.dto.request.DepartmentRequest;
import com.hospital.hms.module.department.dto.response.DepartmentResponse;
import com.hospital.hms.module.department.entity.Department;
import com.hospital.hms.module.department.mapper.DepartmentMapper;
import com.hospital.hms.module.department.repository.DepartmentRepository;
import com.hospital.hms.module.department.service.DepartmentService;
import com.hospital.hms.module.doctor.repository.DoctorRepository;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DepartmentServiceImpl implements DepartmentService {

    private final DepartmentRepository departmentRepository;
    private final DoctorRepository doctorRepository;
    private final DepartmentMapper mapper;

    public DepartmentServiceImpl(DepartmentRepository departmentRepository,
                                 DoctorRepository doctorRepository,
                                 DepartmentMapper mapper) {
        this.departmentRepository = departmentRepository;
        this.doctorRepository = doctorRepository;
        this.mapper = mapper;
    }

    @Override
    @Transactional(readOnly = true)
    public List<DepartmentResponse> listActive() {
        return departmentRepository.findAllByIsActiveTrueOrderByDepartmentName().stream()
                .map(this::withDoctorCount)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public DepartmentResponse getById(Integer departmentId) {
        return withDoctorCount(find(departmentId));
    }

    @Override
    @Transactional
    public DepartmentResponse create(DepartmentRequest request) {
        // uq_department_name would catch this anyway; checking first turns a raw
        // duplicate-key error into a message the UI can actually show.
        if (departmentRepository.existsByDepartmentName(request.departmentName())) {
            throw new BusinessRuleException(
                    "A department named " + request.departmentName() + " already exists");
        }
        Department department = Department.builder()
                .departmentName(request.departmentName())
                .description(request.description())
                .location(request.location())
                .contactNumber(request.contactNumber())
                .isActive(true)
                .build();
        return withDoctorCount(departmentRepository.save(department));
    }

    @Override
    @Transactional
    public DepartmentResponse update(Integer departmentId, DepartmentRequest request) {
        Department department = find(departmentId);
        department.setDepartmentName(request.departmentName());
        department.setDescription(request.description());
        department.setLocation(request.location());
        department.setContactNumber(request.contactNumber());
        return withDoctorCount(departmentRepository.save(department));
    }

    @Override
    @Transactional
    public void deactivate(Integer departmentId) {
        Department department = find(departmentId);
        // fk_doctor_department is ON DELETE RESTRICT, so a department that still
        // has staff must never be removed. Deactivating keeps the history intact
        // and still hides it from the booking screens.
        long doctors = doctorRepository.countByDepartmentIdAndIsActiveTrue(departmentId);
        if (doctors > 0) {
            throw new BusinessRuleException("Cannot deactivate: " + doctors
                    + " active doctor(s) are still assigned to this department");
        }
        department.setIsActive(false);
        departmentRepository.save(department);
    }

    private Department find(Integer departmentId) {
        return departmentRepository.findById(departmentId)
                .orElseThrow(() -> new ResourceNotFoundException("Department", departmentId));
    }

    private DepartmentResponse withDoctorCount(Department department) {
        return mapper.toResponse(department,
                doctorRepository.countByDepartmentIdAndIsActiveTrue(department.getDepartmentId()));
    }
}
