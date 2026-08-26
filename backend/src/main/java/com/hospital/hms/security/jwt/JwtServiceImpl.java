package com.hospital.hms.security.jwt;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import javax.crypto.SecretKey;
import org.springframework.stereotype.Service;

@Service
public class JwtServiceImpl implements JwtService {

    private static final String CLAIM_USER_ID = "uid";
    private static final String CLAIM_PERMISSIONS = "perms";

    private final SecretKey key;
    private final Duration accessTokenExpiry;
    private final Duration refreshTokenExpiry;

    public JwtServiceImpl(JwtProperties properties) {
        this.key = Keys.hmacShaKeyFor(properties.secret().getBytes(StandardCharsets.UTF_8));
        this.accessTokenExpiry = Duration.ofMinutes(properties.accessTokenExpiryMinutes());
        this.refreshTokenExpiry = Duration.ofDays(properties.refreshTokenExpiryDays());
    }

    @Override
    public String generateAccessToken(Integer userId, String username, List<String> permissions) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(username)
                .claim(CLAIM_USER_ID, userId)
                .claim(CLAIM_PERMISSIONS, permissions)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(accessTokenExpiry)))
                .signWith(key)
                .compact();
    }

    @Override
    public String generateRefreshToken(Integer userId) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim(CLAIM_USER_ID, userId)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(refreshTokenExpiry)))
                .signWith(key)
                .compact();
    }

    @Override
    public boolean isValid(String token) {
        try {
            parse(token);
            return true;
        } catch (JwtException | IllegalArgumentException ex) {
            return false;
        }
    }

    @Override
    public String extractUsername(String token) {
        return parse(token).getSubject();
    }

    @Override
    @SuppressWarnings("unchecked")
    public List<String> extractPermissions(String token) {
        Object claim = parse(token).get(CLAIM_PERMISSIONS);
        return claim instanceof List<?> list ? (List<String>) list : List.of();
    }

    private Claims parse(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
