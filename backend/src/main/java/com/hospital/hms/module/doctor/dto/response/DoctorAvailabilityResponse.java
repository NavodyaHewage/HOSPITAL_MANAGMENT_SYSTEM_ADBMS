package com.hospital.hms.module.doctor.dto.response;

import java.math.BigDecimal;

/** One row of sp_search_doctor_availability. */
public record DoctorAvailabilityResponse(
        Integer doctorId,
        String doctorName,
        String specialization,
        BigDecimal consultationFee,
        Long bookingsThatDay) {
}
