package com.hospital.hms.security;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Pins the encoder to MySQL's SHA2(x, 256) output.
 *
 * <p>If these fail, no seeded user can log in: the 60 staff accounts hold
 * digests written by the database, and the encoder has to reproduce them
 * exactly.
 */
class MysqlSha256PasswordEncoderTest {

    private final MysqlSha256PasswordEncoder encoder = new MysqlSha256PasswordEncoder();

    @Test
    @DisplayName("matches the known SHA-256 digest of \"abc\"")
    void producesStandardSha256Hex() {
        // The canonical SHA-256 of "abc"; MySQL's SELECT SHA2('abc', 256) prints the same.
        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
                encoder.encode("abc"));
    }

    @Test
    void producesLowercaseHexOf64Characters() {
        String hash = encoder.encode("Passw0rd!1");
        assertEquals(64, hash.length());
        assertTrue(hash.matches("[0-9a-f]{64}"), "expected lowercase hex, got " + hash);
    }

    @Test
    void matchesTheDigestItProduced() {
        String raw = "Passw0rd!42";
        assertTrue(encoder.matches(raw, encoder.encode(raw)));
    }

    @Test
    void rejectsAWrongPassword() {
        assertFalse(encoder.matches("wrong", encoder.encode("right")));
    }

    @Test
    @DisplayName("accepts an uppercase stored digest")
    void isCaseInsensitiveAboutTheStoredHash() {
        // Defensive: some tools print SHA2 output uppercase. The comparison
        // should not hinge on which tool wrote the row.
        String raw = "Passw0rd!7";
        assertTrue(encoder.matches(raw, encoder.encode(raw).toUpperCase()));
    }

    @Test
    void handlesNullsWithoutThrowing() {
        assertFalse(encoder.matches(null, encoder.encode("x")));
        assertFalse(encoder.matches("x", null));
    }
}
