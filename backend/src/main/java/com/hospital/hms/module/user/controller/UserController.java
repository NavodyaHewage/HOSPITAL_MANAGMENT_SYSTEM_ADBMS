package com.hospital.hms.module.user.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.common.exception.UnauthorizedException;
import com.hospital.hms.module.auth.repository.UserRepository;
import com.hospital.hms.module.user.dto.request.CreateUserRequest;
import com.hospital.hms.module.user.dto.request.RolePermissionRequest;
import com.hospital.hms.module.user.dto.response.UserResponse;
import com.hospital.hms.module.user.repository.view.PermissionMatrixView;
import com.hospital.hms.module.user.repository.view.UserRoleSummaryView;
import com.hospital.hms.module.user.service.UserService;
import jakarta.validation.Valid;
import java.security.Principal;
import java.util.List;
import java.util.Map;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/users")
@PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).USER_MANAGE)")
public class UserController {

    private final UserService userService;
    private final UserRepository userRepository;

    public UserController(UserService userService, UserRepository userRepository) {
        this.userService = userService;
        this.userRepository = userRepository;
    }

    /** Account and role assignment in one transaction. */
    @PostMapping
    public ApiResponse<UserResponse> create(@Valid @RequestBody CreateUserRequest request,
                                            Principal principal) {
        return ApiResponse.ok("User created",
                userService.createUser(request, principal.getName()));
    }

    @GetMapping("/{id}")
    public ApiResponse<UserResponse> getById(@PathVariable Integer id) {
        return ApiResponse.ok(userService.getById(id));
    }

    /** includeInactive=true is what the admin user-management table needs. */
    @GetMapping
    public ApiResponse<PageResponse<UserResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return ApiResponse.ok(userService.list(page, size, includeInactive));
    }

    /** Deactivates rather than deletes, so the audit history stays attributable. */
    @PatchMapping("/{id}/active")
    public ApiResponse<Void> setActive(@PathVariable Integer id,
                                       @RequestParam boolean active,
                                       Principal principal) {
        userService.setActive(id, active, currentUserId(principal));
        return ApiResponse.ok(active ? "User activated" : "User deactivated", null);
    }

    /** Backed by vw_user_role_summary. */
    @GetMapping("/role-summary")
    public ApiResponse<List<UserRoleSummaryView>> roleSummary(
            @RequestParam(defaultValue = "true") boolean activeOnly) {
        return ApiResponse.ok(userService.roleSummary(activeOnly));
    }

    /** Backed by vw_permission_matrix - which role holds which permission. */
    @GetMapping("/permission-matrix")
    public ApiResponse<List<PermissionMatrixView>> permissionMatrix() {
        return ApiResponse.ok(userService.permissionMatrix());
    }

    /** Grant or revoke. The audit row is written in the same transaction. */
    @PostMapping("/role-permissions")
    public ApiResponse<Void> assignOrRevoke(@Valid @RequestBody RolePermissionRequest request,
                                            Principal principal) {
        userService.assignOrRevokePermission(request, currentUserId(principal));
        return ApiResponse.ok(request.action() + " applied", null);
    }

    /** Backed by fn_check_user_permission. */
    @GetMapping("/{id}/has-permission")
    public ApiResponse<Map<String, Boolean>> hasPermission(@PathVariable Integer id,
                                                           @RequestParam String permission) {
        return ApiResponse.ok(Map.of("granted", userService.hasPermission(id, permission)));
    }

    /**
     * The JWT subject is the username; the procedure wants the numeric id so it
     * can stamp @app_user_id for the audit trigger.
     */
    private Integer currentUserId(Principal principal) {
        return userRepository.findByUsername(principal.getName())
                .map(com.hospital.hms.module.auth.entity.User::getUserId)
                .orElseThrow(() -> new UnauthorizedException("Session user no longer exists"));
    }
}
