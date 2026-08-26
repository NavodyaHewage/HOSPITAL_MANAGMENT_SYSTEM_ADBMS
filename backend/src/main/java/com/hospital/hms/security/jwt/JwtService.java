package com.hospital.hms.security.jwt;

import java.util.List;

/**
 * Issues and validates access/refresh tokens. Claims carry the user_id plus the
 * permission names resolved from user_roles -> role_permissions, so method
 * security can check them directly.
 */
public interface JwtService {

    String generateAccessToken(Integer userId, String username, List<String> permissions);

    String generateRefreshToken(Integer userId);

    boolean isValid(String token);

    String extractUsername(String token);

    List<String> extractPermissions(String token);
}
