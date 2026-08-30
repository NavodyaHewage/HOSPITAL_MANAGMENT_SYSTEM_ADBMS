package com.hospital.hms.module;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.hospital.hms.module.appointment.entity.AppointmentStatus;
import com.hospital.hms.module.billing.entity.PaymentMethod;
import com.hospital.hms.module.laboratory.entity.LabOrderStatus;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

/**
 * Three database enums contain values that are not legal Java identifiers -
 * 'No-Show', 'In-Progress' and 'Bank Transfer'. Each is mapped through an
 * AttributeConverter rather than EnumType.STRING, because STRING would persist
 * NO_SHOW / IN_PROGRESS / BANK_TRANSFER and the column would reject the write.
 * These tests pin the exact spellings the columns accept.
 */
class EnumMappingTest {

    @Nested
    @DisplayName("AppointmentStatus")
    class AppointmentStatusTest {

        private final AppointmentStatus.JpaConverter converter = new AppointmentStatus.JpaConverter();

        @Test
        void writesTheHyphenatedDatabaseSpelling() {
            assertEquals("No-Show", converter.convertToDatabaseColumn(AppointmentStatus.NO_SHOW));
            assertEquals("Scheduled", converter.convertToDatabaseColumn(AppointmentStatus.SCHEDULED));
        }

        @Test
        void readsTheHyphenatedDatabaseSpellingBack() {
            assertEquals(AppointmentStatus.NO_SHOW, converter.convertToEntityAttribute("No-Show"));
            assertEquals(AppointmentStatus.CONFIRMED, converter.convertToEntityAttribute("Confirmed"));
        }

        @Test
        void roundTripsEveryConstant() {
            for (AppointmentStatus status : AppointmentStatus.values()) {
                String db = converter.convertToDatabaseColumn(status);
                assertEquals(status, converter.convertToEntityAttribute(db),
                        "round trip failed for " + status);
            }
        }

        @Test
        void onlyScheduledAndConfirmedHoldTheSlot() {
            // These two are exactly the statuses for which the generated column
            // active_slot_key is non-NULL, i.e. the UNIQUE index is in force.
            assertTrue(AppointmentStatus.SCHEDULED.isLive());
            assertTrue(AppointmentStatus.CONFIRMED.isLive());
            assertTrue(!AppointmentStatus.COMPLETED.isLive());
            assertTrue(!AppointmentStatus.CANCELLED.isLive());
            assertTrue(!AppointmentStatus.NO_SHOW.isLive());
        }

        @Test
        void nullPassesThrough() {
            assertNull(converter.convertToDatabaseColumn(null));
            assertNull(converter.convertToEntityAttribute(null));
        }

        @Test
        void rejectsAnUnknownValue() {
            assertThrows(IllegalArgumentException.class,
                    () -> AppointmentStatus.from("Rescheduled"));
        }
    }

    @Nested
    @DisplayName("LabOrderStatus")
    class LabOrderStatusTest {

        private final LabOrderStatus.JpaConverter converter = new LabOrderStatus.JpaConverter();

        @Test
        void roundTripsEveryConstant() {
            for (LabOrderStatus status : LabOrderStatus.values()) {
                String db = converter.convertToDatabaseColumn(status);
                assertEquals(status, converter.convertToEntityAttribute(db),
                        "round trip failed for " + status);
            }
        }

        @Test
        void writesTheHyphenatedDatabaseSpelling() {
            assertEquals("In-Progress", converter.convertToDatabaseColumn(LabOrderStatus.IN_PROGRESS));
        }

        @Test
        void pendingAndInProgressAreBothOutstanding() {
            // fn_find_pending_lab_count counts both - "in progress" is still work
            // the lab owes, so a UI badge driven by this must agree.
            assertTrue(LabOrderStatus.PENDING.isOutstanding());
            assertTrue(LabOrderStatus.IN_PROGRESS.isOutstanding());
            assertTrue(!LabOrderStatus.COMPLETED.isOutstanding());
            assertTrue(!LabOrderStatus.CANCELLED.isOutstanding());
        }
    }

    @Nested
    @DisplayName("PaymentMethod")
    class PaymentMethodTest {

        private final PaymentMethod.JpaConverter converter = new PaymentMethod.JpaConverter();

        @Test
        void writesTheSpacedDatabaseSpelling() {
            assertEquals("Bank Transfer", converter.convertToDatabaseColumn(PaymentMethod.BANK_TRANSFER));
        }

        @Test
        void roundTripsEveryConstant() {
            for (PaymentMethod method : PaymentMethod.values()) {
                String db = converter.convertToDatabaseColumn(method);
                assertEquals(method, converter.convertToEntityAttribute(db),
                        "round trip failed for " + method);
            }
        }
    }
}
