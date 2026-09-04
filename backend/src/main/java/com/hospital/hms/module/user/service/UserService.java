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

    /**
     * @param includeInactive false returns only enabled accounts (the original
     *                        behaviour); true is what the admin user-management
     *                        screen needs - a disabled account has to stay
     *                        visible somewhere, or there is no way to re-enable it
     */
    PageResponse<UserResponse> list(int page, int size, boolean includeInactive);

    /**
     * @param actorUserId the operator flipping the switch, stamped onto the
     *                    audit row trg_users_au_session writes for this change;
     *                    null only when there is no authenticated principal
     */
    void setActive(Integer userId, boolean active, Integer actorUserId);

    List<UserRoleSummaryView> roleSummary(boolean activeOnly);

    List<PermissionMatrixView> permissionMatrix();

    void assignOrRevokePermission(RolePermissionRequest request, Integer actorUserId);

    boolean hasPermission(Integer userId, String permissionName);
}
