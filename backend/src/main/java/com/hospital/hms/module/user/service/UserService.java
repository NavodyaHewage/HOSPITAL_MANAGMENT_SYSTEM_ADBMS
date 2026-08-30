package com.hospital.hms.module.user.service;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.user.dto.request.CreateUserRequest;
import com.hospital.hms.module.user.dto.request.RolePermissionRequest;
import com.hospital.hms.module.user.dto.response.UserResponse;
import com.hospital.hms.module.user.repository.view.PermissionMatrixView;
import com.hospital.hms.module.user.repository.view.UserRoleSummaryView;
import java.util.List;

public interface UserService {

    UserResponse createUser(CreateUserRequest request, String assignedBy);

    UserResponse getById(Integer userId);

    PageResponse<UserResponse> listActive(int page, int size);

    void setActive(Integer userId, boolean active);

    List<UserRoleSummaryView> roleSummary(boolean activeOnly);

    List<PermissionMatrixView> permissionMatrix();

    void assignOrRevokePermission(RolePermissionRequest request, Integer actorUserId);

    boolean hasPermission(Integer userId, String permissionName);
}
