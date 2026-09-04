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
        List<String> roles,
        List<String> permissions) {
}
