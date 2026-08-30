package com.hospital.hms.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * Produces exactly what MySQL's {@code SHA2(password, 256)} produces: a
 * 64-character lowercase hex digest.
 *
 * <p>WHY NOT BCRYPT: the schema hashes passwords itself. The seed writes
 * {@code SHA2(CONCAT('Passw0rd!', n), 256)} for the 60 staff accounts, and
 * {@code sp_create_user_with_role} writes {@code SHA2(p_password, 256)} for
 * every account created through the API. A BCryptPasswordEncoder can never
 * match those digests, so with BCrypt wired in, login fails for every user in
 * the database. The encoder has to agree with whoever writes the hash, and here
 * that is the database.
 *
 * <p>This is demo-grade, and 05_procedures.sql says so itself: unsalted SHA-256
 * is fast to brute-force and identical passwords collide to identical hashes.
 * Moving to bcrypt/argon2 means changing sp_create_user_with_role to accept a
 * pre-hashed value and swapping the bean in {@link SecurityConfig} - the rest
 * of the application is unaffected because everything goes through
 * {@link PasswordEncoder}.
 */
public class MysqlSha256PasswordEncoder implements PasswordEncoder {

    @Override
    public String encode(CharSequence rawPassword) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(rawPassword.toString().getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 is required by the JDK spec", ex);
        }
    }

    @Override
    public boolean matches(CharSequence rawPassword, String encodedPassword) {
        if (rawPassword == null || encodedPassword == null) {
            return false;
        }
        // Constant-time compare so a wrong password cannot be found byte by byte.
        return MessageDigest.isEqual(
                encode(rawPassword).getBytes(StandardCharsets.UTF_8),
                encodedPassword.toLowerCase().getBytes(StandardCharsets.UTF_8));
    }
}
