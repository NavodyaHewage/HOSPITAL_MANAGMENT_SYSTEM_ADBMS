package com.hospital.hms.module.auth.dto.response;

import java.util.List;

public record LoginResponse(
        String accessToken,
        String refreshToken,
        String tokenType,
        long expiresInSeconds,
        CurrentUserResponse user,
        List<String> permissions) {
}
