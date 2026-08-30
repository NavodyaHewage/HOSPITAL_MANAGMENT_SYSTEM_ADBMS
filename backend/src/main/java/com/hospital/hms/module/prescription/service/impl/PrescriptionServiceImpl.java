package com.hospital.hms.module.prescription.service.impl;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.common.exception.ResourceNotFoundException;
import com.hospital.hms.common.support.NameResolver;
import com.hospital.hms.module.pharmacy.entity.Medicine;
import com.hospital.hms.module.pharmacy.repository.MedicineRepository;
import com.hospital.hms.module.prescription.dto.request.PrescriptionRequest;
import com.hospital.hms.module.prescription.dto.response.PrescriptionResponse;
import com.hospital.hms.module.prescription.entity.Prescription;
import com.hospital.hms.module.prescription.entity.PrescriptionItem;
import com.hospital.hms.module.prescription.entity.PrescriptionStatus;
import com.hospital.hms.module.prescription.mapper.PrescriptionMapper;
import com.hospital.hms.module.prescription.repository.PrescriptionItemRepository;
import com.hospital.hms.module.prescription.repository.PrescriptionRepository;
import com.hospital.hms.module.prescription.repository.procedure.PrescriptionProcedureRepository;
import com.hospital.hms.module.prescription.repository.view.ActivePrescriptionView;
import com.hospital.hms.module.prescription.repository.view.PrescriptionViewRepository;
import com.hospital.hms.module.prescription.service.PrescriptionService;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PrescriptionServiceImpl implements PrescriptionService {

    private final PrescriptionRepository prescriptionRepository;
    private final PrescriptionItemRepository itemRepository;
    private final PrescriptionProcedureRepository procedureRepository;
    private final PrescriptionViewRepository viewRepository;
    private final MedicineRepository medicineRepository;
    private final NameResolver names;
    private final PrescriptionMapper mapper;

    public PrescriptionServiceImpl(PrescriptionRepository prescriptionRepository,
                                   PrescriptionItemRepository itemRepository,
                                   PrescriptionProcedureRepository procedureRepository,
                                   PrescriptionViewRepository viewRepository,
                                   MedicineRepository medicineRepository,
                                   NameResolver names,
                                   PrescriptionMapper mapper) {
        this.prescriptionRepository = prescriptionRepository;
        this.itemRepository = itemRepository;
        this.procedureRepository = procedureRepository;
        this.viewRepository = viewRepository;
        this.medicineRepository = medicineRepository;
        this.names = names;
        this.mapper = mapper;
    }

    /** Header and lines land atomically - see sp_create_prescription_with_items. */
    @Override
    public PrescriptionResponse create(PrescriptionRequest request) {
        Integer id = procedureRepository.createWithItems(request);
        return getById(id);
    }

    @Override
    @Transactional(readOnly = true)
    public PrescriptionResponse getById(Integer prescriptionId) {
        Prescription prescription = prescriptionRepository.findById(prescriptionId)
                .orElseThrow(() -> new ResourceNotFoundException("Prescription", prescriptionId));

        List<PrescriptionItem> items = itemRepository.findByPrescriptionId(prescriptionId);

        return mapper.toResponse(prescription,
                names.patientName(prescription.getPatientId()),
                names.doctorName(prescription.getDoctorId()),
                items,
                medicineNames(items),
                procedureRepository.countMedicines(prescriptionId),
                procedureRepository.totalQuantity(prescriptionId));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PrescriptionResponse> listByPatient(Integer patientId, int page, int size) {
        return toPage(prescriptionRepository.findByPatientIdOrderByPrescriptionDateDesc(
                patientId, PageRequest.of(page, size)));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PrescriptionResponse> listByStatus(String status, int page, int size) {
        return toPage(prescriptionRepository.findByStatusOrderByPrescriptionDateDesc(
                PrescriptionStatus.valueOf(status), PageRequest.of(page, size)));
    }

    @Override
    @Transactional(readOnly = true)
    public List<ActivePrescriptionView> activePrescriptions(Integer patientId) {
        return viewRepository.findActive(patientId);
    }

    @Override
    @Transactional
    public PrescriptionResponse updateStatus(Integer prescriptionId, String status) {
        Prescription prescription = prescriptionRepository.findById(prescriptionId)
                .orElseThrow(() -> new ResourceNotFoundException("Prescription", prescriptionId));
        prescription.setStatus(PrescriptionStatus.valueOf(status));
        prescriptionRepository.saveAndFlush(prescription);
        return getById(prescriptionId);
    }

    /**
     * Builds a page without going back to the database per row: the items for
     * every prescription on the page are fetched in one query, then grouped.
     */
    private PageResponse<PrescriptionResponse> toPage(Page<Prescription> page) {
        List<Prescription> rows = page.getContent();
        List<Integer> ids = rows.stream().map(Prescription::getPrescriptionId).toList();

        Map<Integer, List<PrescriptionItem>> itemsByPrescription = ids.isEmpty()
                ? Map.of()
                : itemRepository.findByPrescriptionIdIn(ids).stream()
                        .collect(Collectors.groupingBy(PrescriptionItem::getPrescriptionId));

        List<PrescriptionItem> allItems = itemsByPrescription.values().stream()
                .flatMap(List::stream).toList();
        Map<Integer, String> medicines = medicineNames(allItems);

        Map<Integer, String> patients = names.patientNames(rows, Prescription::getPatientId);
        Map<Integer, String> doctors = names.doctorNames(rows, Prescription::getDoctorId);

        var content = rows.stream()
                .map(p -> {
                    List<PrescriptionItem> items =
                            itemsByPrescription.getOrDefault(p.getPrescriptionId(), List.of());
                    // Counted in Java here rather than through the SQL functions:
                    // the rows are already loaded, and calling the functions would
                    // be two extra round trips per row on a listing screen.
                    int distinct = (int) items.stream()
                            .map(PrescriptionItem::getMedicineId).distinct().count();
                    int total = items.stream()
                            .mapToInt(PrescriptionItem::getQuantity).sum();
                    return mapper.toResponse(p,
                            patients.get(p.getPatientId()),
                            doctors.get(p.getDoctorId()),
                            items, medicines, distinct, total);
                })
                .toList();

        return new PageResponse<>(content, page.getNumber(), page.getSize(),
                page.getTotalElements(), page.getTotalPages());
    }

    private Map<Integer, String> medicineNames(List<PrescriptionItem> items) {
        List<Integer> ids = items.stream()
                .map(PrescriptionItem::getMedicineId).distinct().toList();
        if (ids.isEmpty()) {
            return Map.of();
        }
        return medicineRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(Medicine::getMedicineId,
                        Medicine::getMedicineName, (a, b) -> a));
    }
}
