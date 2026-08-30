package com.hospital.hms.security.rbac;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Guards the one mismatch that fails silently.
 *
 * <p>A JWT carries the permission names read out of the permissions table, and
 * {@code @PreAuthorize} compares against {@link Permissions} literally. A
 * constant that does not exist in the table can never be granted, so every
 * endpoint guarding on it returns 403 for everyone - with no error, no warning
 * and nothing in the log. This test reads the seed SQL and fails the build the
 * moment the two drift apart.
 */
class PermissionsIntegrityTest {

    /** Matches the quoted first column of each row in the INSERT INTO permissions block. */
    private static final Pattern SEED_ROW = Pattern.compile("\\('([A-Z_]+)'\\s*,\\s*'");

    private static final Path SEED_FILE =
            Path.of("..", "database", "seed", "02_seed_data.sql");

    @Test
    @DisplayName("every Permissions constant exists in the seeded permissions table")
    void constantsMatchSeededPermissions() throws IOException {
        Set<String> seeded = readSeededPermissionNames();

        assertTrue(seeded.size() >= 13,
                "Parsed only " + seeded.size() + " permissions from the seed file - "
                        + "the INSERT INTO permissions block may have moved or changed shape");

        Set<String> declared = new LinkedHashSet<>(Permissions.ALL);

        Set<String> missingFromDatabase = new LinkedHashSet<>(declared);
        missingFromDatabase.removeAll(seeded);
        assertEquals(Set.of(), missingFromDatabase,
                "These constants are not in the permissions table, so @PreAuthorize on them "
                        + "denies every caller: " + missingFromDatabase);

        Set<String> missingFromJava = new LinkedHashSet<>(seeded);
        missingFromJava.removeAll(declared);
        assertEquals(Set.of(), missingFromJava,
                "These permissions are seeded but have no Java constant, so nothing can "
                        + "guard on them: " + missingFromJava);
    }

    private Set<String> readSeededPermissionNames() throws IOException {
        String sql = Files.readString(SEED_FILE, StandardCharsets.UTF_8);

        int start = sql.indexOf("INSERT INTO permissions");
        assertTrue(start >= 0, "Could not find the INSERT INTO permissions block in " + SEED_FILE);
        int end = sql.indexOf(';', start);

        Matcher matcher = SEED_ROW.matcher(sql.substring(start, end));
        Set<String> names = new LinkedHashSet<>();
        while (matcher.find()) {
            names.add(matcher.group(1));
        }
        return names;
    }
}
