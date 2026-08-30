package com.hospital.hms.module.user.service.impl;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.common.exception.ResourceNotFoundException;
import com.hospital.hms.module.auth.entity.User;
import com.hospital.hms.module.auth.repository.UserRepository;
import com.hospital.hms.module.user.dto.request.CreateUserRequest;
import com.hospital.hms.module.user.dto.request.RolePermissionRequest;
import com.hospital.hms.module.user.dto.response.UserResponse;
import com.hospital.hms.module.user.repository.procedure.UserProcedureRepository;
import com.hospital.hms.module.user.repository.view.PermissionMatrixView;
import com.hospital.hms.module.user.repository.view.UserRoleSummaryView;
import com.hospital.hms.module.user.repository.view.UserViewRepository;
import com.hospital.hms.module.user.service.UserService;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final UserProcedureRepository procedureRepository;
    private final UserViewRepository viewRepository;

    public UserServiceImpl(UserRepository userRepository,
                           UserProcedureRepository procedureRepository,
                           UserViewRepository viewRepository) {
        this.userRepository = userRepository;
        this.procedureRepository = procedureRepository;
        this.viewRepository = viewRepository;
    }

    /**
     * No @Transactional - sp_create_user_with_role owns its transaction and
     * raises a clean message on a duplicate username or unknown role.
     */
    @Override
    public UserResponse createUser(CreateUserRequest request, String assignedBy) {
        Integer userId = procedureRepository.createUserWithRole(request, assignedBy);
        return getById(userId);
    }

    @Override
    @Transactional(readOnly = true)
    public UserResponse getById(Integer userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", userId));
        return toResponse(user);
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<UserResponse> listActive(int page, int size) {
        Page<User> result = userRepository.findAllByIsActiveTrue(
                PageRequest.of(page, size, Sort.by("username").ascending()));

        var content = result.getContent().stream().map(this::toResponse).toList();
        return new PageResponse<>(content, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }

    /**
     * Deactivates rather than deletes. audit_logs.user_id is ON DELETE SET NULL,
     * so removing a user would anonymise their entire audit history - exactly
     * the history you most want to keep. trg_users_au_session records the
     * is_active change automatically.
     */
    @Override
    @Transactional
    public void setActive(Integer userId, boolean active) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", userId));
        user.setIsActive(active);
        userRepository.saveAndFlush(user);
    }

    @Override
    @Transactional(readOnly = true)
    public List<UserRoleSummaryView> roleSummary(boolean activeOnly) {
        return viewRepository.findUserRoleSummary(activeOnly);
    }

    @Override
    @Transactional(readOnly = true)
    public List<PermissionMatrixView> permissionMatrix() {
        return viewRepository.findPermissionMatrix();
    }

    /** Privilege changes are audited by the procedure, inside its transaction. */
    @Override
    public void assignOrRevokePermission(RolePermissionRequest request, Integer actorUserId) {
        procedureRepository.assignOrRevoke(request.roleId(), request.permissionId(),
                request.action(), actorUserId);
    }

    @Override
    @Transactional(readOnly = true)
    public boolean hasPermission(Integer userId, String permissionName) {
        return procedureRepository.hasPermission(userId, permissionName);
    }

    private UserResponse toResponse(User user) {
        return new UserResponse(
                user.getUserId(),
                user.getUsername(),
                user.getFullName(),
                user.getEmail(),
                user.getPhone(),
                user.getIsActive(),
                user.getLastLogin(),
                user.getLastLogout(),
                userRepository.findRoleNames(user.getUserId()),
                userRepository.findPermissionNames(user.getUserId()));
    }
}
