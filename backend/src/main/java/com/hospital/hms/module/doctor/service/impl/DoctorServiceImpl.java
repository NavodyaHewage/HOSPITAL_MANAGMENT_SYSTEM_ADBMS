package com.hospital.hms.module.doctor.service.impl;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.common.exception.BusinessRuleException;
import com.hospital.hms.common.exception.ResourceNotFoundException;
import com.hospital.hms.module.department.entity.Department;
import com.hospital.hms.module.department.repository.DepartmentRepository;
import com.hospital.hms.module.doctor.dto.request.DoctorRequest;
import com.hospital.hms.module.doctor.dto.response.DoctorAvailabilityResponse;
import com.hospital.hms.module.doctor.dto.response.DoctorResponse;
import com.hospital.hms.module.doctor.entity.Doctor;
import com.hospital.hms.module.doctor.mapper.DoctorMapper;
import com.hospital.hms.module.doctor.repository.DoctorRepository;
import com.hospital.hms.module.doctor.repository.procedure.DoctorProcedureRepository;
import com.hospital.hms.module.doctor.service.DoctorService;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DoctorServiceImpl implements DoctorService {

    private final DoctorRepository doctorRepository;
    private final DepartmentRepository departmentRepository;
    private final DoctorProcedureRepository procedureRepository;
    private final DoctorMapper mapper;

    public DoctorServiceImpl(DoctorRepository doctorRepository,
                             DepartmentRepository departmentRepository,
                             DoctorProcedureRepository procedureRepository,
                             DoctorMapper mapper) {
        this.doctorRepository = doctorRepository;
        this.departmentRepository = departmentRepository;
        this.procedureRepository = procedureRepository;
        this.mapper = mapper;
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<DoctorResponse> search(String term, Integer departmentId, int page, int size) {
        var pageable = PageRequest.of(page, size, Sort.by("lastName").ascending());
        var result = doctorRepository.search(term, departmentId, pageable);

        // One lookup for the whole page instead of one per row - the N+1 that
        // would otherwise show up immediately in the SQL log during the viva.
        Map<Integer, String> names = departmentNames(result.getContent());
        var content = result.getContent().stream()
                .map(d -> mapper.toResponse(d, names.get(d.getDepartmentId())))
                .toList();

        return new PageResponse<>(content, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }

    @Override
    @Transactional(readOnly = true)
    public DoctorResponse getById(Integer doctorId) {
        Doctor doctor = find(doctorId);
        return mapper.toResponse(doctor, departmentName(doctor.getDepartmentId()));
    }

    @Override
    @Transactional(readOnly = true)
    public List<DoctorResponse> listByDepartment(Integer departmentId) {
        String name = departmentName(departmentId);
        return doctorRepository.findByDepartmentIdAndIsActiveTrue(departmentId).stream()
                .map(d -> mapper.toResponse(d, name))
                .toList();
    }

    @Override
    @Transactional
    public DoctorResponse create(DoctorRequest request) {
        requireDepartment(request.departmentId());
        doctorRepository.findByLicenseNumber(request.licenseNumber()).ifPresent(existing -> {
            throw new BusinessRuleException(
                    "License number " + request.licenseNumber() + " is already registered");
        });

        Doctor doctor = Doctor.builder()
                .departmentId(request.departmentId())
                .firstName(request.firstName())
                .lastName(request.lastName())
                .specialization(request.specialization())
                .qualification(request.qualification())
                .licenseNumber(request.licenseNumber())
                .phone(request.phone())
                .email(request.email())
                .consultationFee(request.consultationFee())
                .isActive(true)
                .build();

        Doctor saved = doctorRepository.save(doctor);
        return mapper.toResponse(saved, departmentName(saved.getDepartmentId()));
    }

    @Override
    @Transactional
    public DoctorResponse update(Integer doctorId, DoctorRequest request) {
        Doctor doctor = find(doctorId);
        requireDepartment(request.departmentId());

        doctor.setDepartmentId(request.departmentId());
        doctor.setFirstName(request.firstName());
        doctor.setLastName(request.lastName());
        doctor.setSpecialization(request.specialization());
        doctor.setQualification(request.qualification());
        doctor.setLicenseNumber(request.licenseNumber());
        doctor.setPhone(request.phone());
        doctor.setEmail(request.email());
        doctor.setConsultationFee(request.consultationFee());

        Doctor saved = doctorRepository.save(doctor);
        return mapper.toResponse(saved, departmentName(saved.getDepartmentId()));
    }

    @Override
    @Transactional
    public void deactivate(Integer doctorId) {
        Doctor doctor = find(doctorId);
        // trg_appointments_bi_validate rejects new bookings for an inactive
        // doctor, so flipping this flag is what actually closes their diary.
        doctor.setIsActive(false);
        doctorRepository.save(doctor);
    }

    @Override
    @Transactional(readOnly = true)
    public List<DoctorAvailabilityResponse> searchAvailability(Integer departmentId,
                                                               LocalDate date,
                                                               LocalTime time) {
        return procedureRepository.searchAvailability(departmentId, date, time);
    }

    @Override
    @Transactional(readOnly = true)
    public boolean isSlotFree(Integer doctorId, LocalDate date, LocalTime time) {
        return procedureRepository.isSlotFree(doctorId, date, time);
    }

    private Doctor find(Integer doctorId) {
        return doctorRepository.findById(doctorId)
                .orElseThrow(() -> new ResourceNotFoundException("Doctor", doctorId));
    }

    private void requireDepartment(Integer departmentId) {
        if (!departmentRepository.existsById(departmentId)) {
            throw new ResourceNotFoundException("Department", departmentId);
        }
    }

    private String departmentName(Integer departmentId) {
        return departmentRepository.findById(departmentId)
                .map(Department::getDepartmentName)
                .orElse(null);
    }

    private Map<Integer, String> departmentNames(List<Doctor> doctors) {
        List<Integer> ids = doctors.stream().map(Doctor::getDepartmentId).distinct().toList();
        return departmentRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(Department::getDepartmentId,
                        Department::getDepartmentName,
                        (a, b) -> a));
    }
}
