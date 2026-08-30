package com.hospital.hms.module.doctor.service;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.doctor.dto.request.DoctorRequest;
import com.hospital.hms.module.doctor.dto.response.DoctorAvailabilityResponse;
import com.hospital.hms.module.doctor.dto.response.DoctorResponse;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

public interface DoctorService {

    PageResponse<DoctorResponse> search(String term, Integer departmentId, int page, int size);

    DoctorResponse getById(Integer doctorId);

    List<DoctorResponse> listByDepartment(Integer departmentId);

    DoctorResponse create(DoctorRequest request);

    DoctorResponse update(Integer doctorId, DoctorRequest request);

    void deactivate(Integer doctorId);

    List<DoctorAvailabilityResponse> searchAvailability(Integer departmentId, LocalDate date, LocalTime time);

    boolean isSlotFree(Integer doctorId, LocalDate date, LocalTime time);
}
