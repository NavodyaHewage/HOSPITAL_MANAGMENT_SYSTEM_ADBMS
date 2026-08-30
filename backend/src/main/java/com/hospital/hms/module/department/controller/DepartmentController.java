package com.hospital.hms.module.department.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.module.department.dto.request.DepartmentRequest;
import com.hospital.hms.module.department.dto.response.DepartmentResponse;
import com.hospital.hms.module.department.service.DepartmentService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/departments")
public class DepartmentController {

    private final DepartmentService departmentService;

    public DepartmentController(DepartmentService departmentService) {
        this.departmentService = departmentService;
    }

    /** Any signed-in user may read the list - it drives every department dropdown. */
    @GetMapping
    public ApiResponse<List<DepartmentResponse>> listActive() {
        return ApiResponse.ok(departmentService.listActive());
    }

    @GetMapping("/{id}")
    public ApiResponse<DepartmentResponse> getById(@PathVariable Integer id) {
        return ApiResponse.ok(departmentService.getById(id));
    }

    @PostMapping
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).USER_MANAGE)")
    public ApiResponse<DepartmentResponse> create(@Valid @RequestBody DepartmentRequest request) {
        return ApiResponse.ok("Department created", departmentService.create(request));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).USER_MANAGE)")
    public ApiResponse<DepartmentResponse> update(@PathVariable Integer id,
                                                  @Valid @RequestBody DepartmentRequest request) {
        return ApiResponse.ok("Department updated", departmentService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).USER_MANAGE)")
    public ApiResponse<Void> deactivate(@PathVariable Integer id) {
        departmentService.deactivate(id);
        return ApiResponse.ok("Department deactivated", null);
    }
}
