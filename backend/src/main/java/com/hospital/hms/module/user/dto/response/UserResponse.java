package com.hospital.hms.module.user.dto.response;

import java.time.LocalDateTime;
import java.util.List;

public record UserResponse(
        Integer userId,
        String username,
        String fullName,
        String email,
        String phone,
        Boolean isActive,
        LocalDateTime lastLogin,
        LocalDateTime lastLogout,
        LocalDateTime createdAt,
        /** True once sp_handle_failed_login has locked this account. */
        Boolean isLocked,
        /** Consecutive wrong passwords since the last success or admin unlock. */
        Integer failedAttempts,
        List<String> roles,
        List<String> permissions) {
}
