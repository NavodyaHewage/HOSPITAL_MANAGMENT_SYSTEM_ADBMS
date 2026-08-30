package com.hospital.hms.module.auth.dto.response;

import java.time.LocalDateTime;
import java.util.List;

public record CurrentUserResponse(
        Integer userId,
        String username,
        String fullName,
        String email,
        String phone,
        Boolean isActive,
        LocalDateTime lastLogin,
        List<String> roles,
        List<String> permissions) {
}
