package com.hospital.hms.module.user.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.common.exception.UnauthorizedException;
import com.hospital.hms.module.auth.entity.User;
import com.hospital.hms.module.auth.repository.UserRepository;
import com.hospital.hms.module.user.service.UserService;
import java.security.Principal;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Exposes the account-unlock action at the literal path given in the Member 5
 * task list: {@code PATCH /api/v1/users/{id}/unlock}.
 *
 * <p>Every other endpoint in this API is unversioned ({@code /api/users/**},
 * {@code /api/patients/**}, ...). Rather than retrofit a "/v1" prefix onto
 * UserController's other eight routes to fit one requested path, this one
 * versioned route lives in its own small controller. Same USER_MANAGE gate,
 * same {@link UserService#unlockAccount}, same audit trail
 * (sp_unlock_user_account stamps {@code @app_user_id = p_admin_id} itself).
 */
@RestController
@RequestMapping("/v1/users")
@PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).USER_MANAGE)")
public class UserUnlockController {

    private final UserService userService;
    private final UserRepository userRepository;

    public UserUnlockController(UserService userService, UserRepository userRepository) {
        this.userService = userService;
        this.userRepository = userRepository;
    }

    @PatchMapping("/{id}/unlock")
    public ApiResponse<Void> unlock(@PathVariable Integer id, Principal principal) {
        userService.unlockAccount(id, currentUserId(principal));
        return ApiResponse.ok("Account unlocked", null);
    }

    /** The JWT subject is the username; the procedure wants the admin's numeric id. */
    private Integer currentUserId(Principal principal) {
        return userRepository.findByUsername(principal.getName())
                .map(User::getUserId)
                .orElseThrow(() -> new UnauthorizedException("Session user no longer exists"));
    }
}
