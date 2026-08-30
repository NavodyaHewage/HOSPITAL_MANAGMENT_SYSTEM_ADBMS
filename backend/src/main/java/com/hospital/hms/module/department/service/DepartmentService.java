package com.hospital.hms.module.department.service;

import com.hospital.hms.module.department.dto.request.DepartmentRequest;
import com.hospital.hms.module.department.dto.response.DepartmentResponse;
import java.util.List;

public interface DepartmentService {

    List<DepartmentResponse> listActive();

    DepartmentResponse getById(Integer departmentId);

    DepartmentResponse create(DepartmentRequest request);

    DepartmentResponse update(Integer departmentId, DepartmentRequest request);

    void deactivate(Integer departmentId);
}
