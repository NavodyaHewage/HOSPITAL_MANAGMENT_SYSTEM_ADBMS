package com.hospital.hms.module.appointment.service.impl;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.common.exception.ResourceNotFoundException;
import com.hospital.hms.module.appointment.dto.request.BookAppointmentRequest;
import com.hospital.hms.module.appointment.dto.request.UpdateAppointmentStatusRequest;
import com.hospital.hms.module.appointment.dto.response.AppointmentResponse;
import com.hospital.hms.module.appointment.entity.Appointment;
import com.hospital.hms.module.appointment.entity.AppointmentStatus;
import com.hospital.hms.module.appointment.mapper.AppointmentMapper;
import com.hospital.hms.module.appointment.repository.AppointmentRepository;
import com.hospital.hms.module.appointment.repository.procedure.AppointmentProcedureRepository;
import com.hospital.hms.module.appointment.repository.view.AppointmentViewRepository;
import com.hospital.hms.module.appointment.repository.view.DoctorDailyScheduleView;
import com.hospital.hms.module.appointment.repository.view.PatientAppointmentHistoryView;
import com.hospital.hms.module.appointment.repository.view.UpcomingAppointmentView;
import com.hospital.hms.module.appointment.service.AppointmentService;
import com.hospital.hms.module.doctor.entity.Doctor;
import com.hospital.hms.module.doctor.repository.DoctorRepository;
import com.hospital.hms.module.patient.entity.Patient;
import com.hospital.hms.module.patient.repository.PatientRepository;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AppointmentServiceImpl implements AppointmentService {

    private final AppointmentRepository appointmentRepository;
    private final AppointmentProcedureRepository procedureRepository;
    private final AppointmentViewRepository viewRepository;
    private final PatientRepository patientRepository;
    private final DoctorRepository doctorRepository;
    private final AppointmentMapper mapper;

    public AppointmentServiceImpl(AppointmentRepository appointmentRepository,
                                  AppointmentProcedureRepository procedureRepository,
                                  AppointmentViewRepository viewRepository,
                                  PatientRepository patientRepository,
                                  DoctorRepository doctorRepository,
                                  AppointmentMapper mapper) {
        this.appointmentRepository = appointmentRepository;
        this.procedureRepository = procedureRepository;
        this.viewRepository = viewRepository;
        this.patientRepository = patientRepository;
        this.doctorRepository = doctorRepository;
        this.mapper = mapper;
    }

    /**
     * No @Transactional on purpose. sp_book_or_reschedule_appointment runs its
     * own START TRANSACTION / COMMIT and rolls itself back through an EXIT
     * HANDLER. Wrapping a Spring transaction around it would leave Spring
     * believing it still controls a transaction the procedure already committed.
     */
    @Override
    public AppointmentResponse bookOrReschedule(BookAppointmentRequest request) {
        Integer id = procedureRepository.bookOrReschedule(request);
        return getById(id);
    }

    @Override
    @Transactional(readOnly = true)
    public AppointmentResponse getById(Integer appointmentId) {
        Appointment appointment = find(appointmentId);
        return mapper.toResponse(appointment,
                patientName(appointment.getPatientId()),
                doctorName(appointment.getDoctorId()));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<AppointmentResponse> search(Integer doctorId, Integer patientId, String status,
                                                    LocalDate fromDate, LocalDate toDate,
                                                    int page, int size) {
        var pageable = PageRequest.of(page, size,
                Sort.by("appointmentDate").descending().and(Sort.by("appointmentTime").descending()));

        var result = appointmentRepository.search(doctorId, patientId,
                AppointmentStatus.from(status), fromDate, toDate, pageable);

        // Resolve every name in two queries rather than two per row.
        Map<Integer, String> patients = patientNames(result.getContent());
        Map<Integer, String> doctors = doctorNames(result.getContent());

        var content = result.getContent().stream()
                .map(a -> mapper.toResponse(a,
                        patients.get(a.getPatientId()),
                        doctors.get(a.getDoctorId())))
                .toList();

        return new PageResponse<>(content, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }

    /**
     * Status transitions are policed by trg_appointments_bu_validate - a
     * completed appointment cannot be re-opened, a cancelled one cannot be
     * completed. Those rules are NOT duplicated here; an illegal transition
     * comes back as SQLSTATE 45000 and surfaces as HTTP 409.
     */
    @Override
    @Transactional
    public AppointmentResponse updateStatus(Integer appointmentId,
                                            UpdateAppointmentStatusRequest request) {
        Appointment appointment = find(appointmentId);
        appointment.setStatus(AppointmentStatus.from(request.status()));
        if (request.notes() != null) {
            appointment.setNotes(request.notes());
        }
        appointmentRepository.saveAndFlush(appointment);
        return getById(appointmentId);
    }

    @Override
    @Transactional
    public AppointmentResponse cancel(Integer appointmentId) {
        Appointment appointment = find(appointmentId);
        appointment.setStatus(AppointmentStatus.CANCELLED);
        appointmentRepository.saveAndFlush(appointment);
        // Cancelling nulls active_slot_key, which frees the slot for rebooking.
        return getById(appointmentId);
    }

    @Override
    @Transactional(readOnly = true)
    public List<UpcomingAppointmentView> upcoming(Integer doctorId, int limit) {
        return viewRepository.findUpcoming(doctorId, limit);
    }

    @Override
    @Transactional(readOnly = true)
    public List<DoctorDailyScheduleView> doctorSchedule(Integer doctorId, LocalDate date) {
        return viewRepository.findDoctorSchedule(doctorId, date);
    }

    @Override
    @Transactional(readOnly = true)
    public List<PatientAppointmentHistoryView> patientHistory(Integer patientId) {
        return viewRepository.findPatientHistory(patientId);
    }

    @Override
    @Transactional(readOnly = true)
    public int countForPatient(Integer patientId, String status) {
        return procedureRepository.countForPatient(patientId, status);
    }

    private Appointment find(Integer appointmentId) {
        return appointmentRepository.findById(appointmentId)
                .orElseThrow(() -> new ResourceNotFoundException("Appointment", appointmentId));
    }

    private String patientName(Integer patientId) {
        return patientRepository.findById(patientId)
                .map(p -> p.getFirstName() + " " + p.getLastName())
                .orElse(null);
    }

    private String doctorName(Integer doctorId) {
        return doctorRepository.findById(doctorId)
                .map(d -> d.getFirstName() + " " + d.getLastName())
                .orElse(null);
    }

    private Map<Integer, String> patientNames(List<Appointment> appointments) {
        List<Integer> ids = appointments.stream().map(Appointment::getPatientId).distinct().toList();
        return patientRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(Patient::getPatientId,
                        p -> p.getFirstName() + " " + p.getLastName(), (a, b) -> a));
    }

    private Map<Integer, String> doctorNames(List<Appointment> appointments) {
        List<Integer> ids = appointments.stream().map(Appointment::getDoctorId).distinct().toList();
        return doctorRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(Doctor::getDoctorId,
                        d -> d.getFirstName() + " " + d.getLastName(), (a, b) -> a));
    }
}
