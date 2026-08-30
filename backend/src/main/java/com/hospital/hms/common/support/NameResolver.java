package com.hospital.hms.common.support;

import com.hospital.hms.module.doctor.entity.Doctor;
import com.hospital.hms.module.doctor.repository.DoctorRepository;
import com.hospital.hms.module.patient.entity.Patient;
import com.hospital.hms.module.patient.repository.PatientRepository;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;

/**
 * Resolves patient and doctor display names.
 *
 * <p>Consultations, prescriptions, lab orders, bills and dispensations all need
 * "who was this for, and who ordered it". Without a shared helper each service
 * grows its own copy, and the batch variants below are the difference between
 * one query per page and one query per row - the N+1 that shows up immediately
 * in the SQL log.
 */
@Component
public class NameResolver {

    private final PatientRepository patientRepository;
    private final DoctorRepository doctorRepository;

    public NameResolver(PatientRepository patientRepository, DoctorRepository doctorRepository) {
        this.patientRepository = patientRepository;
        this.doctorRepository = doctorRepository;
    }

    public String patientName(Integer patientId) {
        if (patientId == null) {
            return null;
        }
        return patientRepository.findById(patientId).map(NameResolver::fullName).orElse(null);
    }

    public String doctorName(Integer doctorId) {
        if (doctorId == null) {
            return null;
        }
        return doctorRepository.findById(doctorId).map(NameResolver::fullName).orElse(null);
    }

    /** One query for a whole page of rows. */
    public <T> Map<Integer, String> patientNames(Collection<T> rows, Function<T, Integer> idOf) {
        List<Integer> ids = distinctIds(rows, idOf);
        return patientRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(Patient::getPatientId, NameResolver::fullName, (a, b) -> a));
    }

    public <T> Map<Integer, String> doctorNames(Collection<T> rows, Function<T, Integer> idOf) {
        List<Integer> ids = distinctIds(rows, idOf);
        return doctorRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(Doctor::getDoctorId, NameResolver::fullName, (a, b) -> a));
    }

    private <T> List<Integer> distinctIds(Collection<T> rows, Function<T, Integer> idOf) {
        return rows.stream().map(idOf).filter(java.util.Objects::nonNull).distinct().toList();
    }

    private static String fullName(Patient p) {
        return p.getFirstName() + " " + p.getLastName();
    }

    private static String fullName(Doctor d) {
        return d.getFirstName() + " " + d.getLastName();
    }
}
