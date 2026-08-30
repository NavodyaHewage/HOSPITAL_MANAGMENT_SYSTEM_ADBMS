package com.hospital.hms.module.pharmacy.service.impl;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.common.exception.ResourceNotFoundException;
import com.hospital.hms.common.support.NameResolver;
import com.hospital.hms.module.pharmacy.dto.request.DispenseRequest;
import com.hospital.hms.module.pharmacy.dto.request.ReceiveStockRequest;
import com.hospital.hms.module.pharmacy.dto.request.StockAdjustmentRequest;
import com.hospital.hms.module.pharmacy.dto.response.DispensationResponse;
import com.hospital.hms.module.pharmacy.dto.response.InventoryBatchResponse;
import com.hospital.hms.module.pharmacy.dto.response.MedicineResponse;
import com.hospital.hms.module.pharmacy.entity.InventoryBatch;
import com.hospital.hms.module.pharmacy.entity.Medicine;
import com.hospital.hms.module.pharmacy.entity.PharmacyDispensation;
import com.hospital.hms.module.pharmacy.mapper.PharmacyMapper;
import com.hospital.hms.module.pharmacy.repository.InventoryBatchRepository;
import com.hospital.hms.module.pharmacy.repository.MedicineRepository;
import com.hospital.hms.module.pharmacy.repository.PharmacyDispensationRepository;
import com.hospital.hms.module.pharmacy.repository.procedure.PharmacyProcedureRepository;
import com.hospital.hms.module.pharmacy.repository.view.CurrentMedicineStockView;
import com.hospital.hms.module.pharmacy.repository.view.DispensingHistoryView;
import com.hospital.hms.module.pharmacy.repository.view.ExpiringBatchView;
import com.hospital.hms.module.pharmacy.repository.view.PharmacyViewRepository;
import com.hospital.hms.module.pharmacy.service.PharmacyService;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PharmacyServiceImpl implements PharmacyService {

    private final MedicineRepository medicineRepository;
    private final InventoryBatchRepository batchRepository;
    private final PharmacyDispensationRepository dispensationRepository;
    private final PharmacyProcedureRepository procedureRepository;
    private final PharmacyViewRepository viewRepository;
    private final NameResolver names;
    private final PharmacyMapper mapper;

    public PharmacyServiceImpl(MedicineRepository medicineRepository,
                               InventoryBatchRepository batchRepository,
                               PharmacyDispensationRepository dispensationRepository,
                               PharmacyProcedureRepository procedureRepository,
                               PharmacyViewRepository viewRepository,
                               NameResolver names,
                               PharmacyMapper mapper) {
        this.medicineRepository = medicineRepository;
        this.batchRepository = batchRepository;
        this.dispensationRepository = dispensationRepository;
        this.procedureRepository = procedureRepository;
        this.viewRepository = viewRepository;
        this.names = names;
        this.mapper = mapper;
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<MedicineResponse> searchMedicines(String term, String category,
                                                          int page, int size) {
        Page<Medicine> result = medicineRepository.search(term, category,
                PageRequest.of(page, size));

        // Stock figures come from vw_current_medicine_stock in one query rather
        // than three function calls per row - on a 150-medicine list that is the
        // difference between 1 query and 450.
        Map<Integer, CurrentMedicineStockView> stock = viewRepository.findCurrentStock(false).stream()
                .collect(Collectors.toMap(CurrentMedicineStockView::getMedicineId, v -> v, (a, b) -> a));

        var content = result.getContent().stream()
                .map(m -> {
                    CurrentMedicineStockView view = stock.get(m.getMedicineId());
                    int available = view == null || view.getTotalAvailable() == null
                            ? 0 : view.getTotalAvailable().intValue();
                    boolean reorder = view != null && "REORDER".equals(view.getStockStatus());
                    return mapper.toMedicineResponse(m, available, reorder, null);
                })
                .toList();

        return new PageResponse<>(content, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }

    /** Single medicine - here the exact SQL functions are worth the round trip. */
    @Override
    @Transactional(readOnly = true)
    public MedicineResponse getMedicine(Integer medicineId) {
        Medicine medicine = medicineRepository.findById(medicineId)
                .orElseThrow(() -> new ResourceNotFoundException("Medicine", medicineId));

        return mapper.toMedicineResponse(medicine,
                procedureRepository.availableStock(medicineId),
                procedureRepository.needsReorder(medicineId),
                procedureRepository.stockValue(medicineId));
    }

    /** No @Transactional - sp_receive_medicine_stock owns its transaction. */
    @Override
    public InventoryBatchResponse receiveStock(ReceiveStockRequest request, String performedBy) {
        Integer batchId = procedureRepository.receiveStock(request, performedBy);
        return getBatch(batchId);
    }

    @Override
    public DispensationResponse dispense(DispenseRequest request, String dispensedBy) {
        Integer dispensationId = procedureRepository.dispense(request, dispensedBy);
        return getDispensation(dispensationId);
    }

    @Override
    public void adjustStock(StockAdjustmentRequest request, String performedBy) {
        procedureRepository.adjustStock(request, performedBy);
    }

    @Override
    @Transactional(readOnly = true)
    public InventoryBatchResponse getBatch(Integer batchId) {
        InventoryBatch batch = batchRepository.findById(batchId)
                .orElseThrow(() -> new ResourceNotFoundException("Inventory batch", batchId));
        return mapper.toBatchResponse(batch, medicineName(batch.getMedicineId()));
    }

    @Override
    @Transactional(readOnly = true)
    public List<InventoryBatchResponse> listUsableBatches(Integer medicineId) {
        String name = medicineName(medicineId);
        return batchRepository.findUsableBatches(medicineId).stream()
                .map(b -> mapper.toBatchResponse(b, name))
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public List<CurrentMedicineStockView> currentStock(boolean onlyReorder) {
        return viewRepository.findCurrentStock(onlyReorder);
    }

    @Override
    @Transactional(readOnly = true)
    public List<ExpiringBatchView> expiringBatches() {
        return viewRepository.findExpiringBatches();
    }

    @Override
    @Transactional(readOnly = true)
    public List<DispensingHistoryView> dispensingHistory(Integer patientId, int limit) {
        return viewRepository.findDispensingHistory(patientId, limit);
    }

    @Override
    @Transactional(readOnly = true)
    public DispensationResponse getDispensation(Integer dispensationId) {
        PharmacyDispensation dispensation = dispensationRepository.findById(dispensationId)
                .orElseThrow(() -> new ResourceNotFoundException("Dispensation", dispensationId));
        return mapper.toDispensationResponse(dispensation,
                names.patientName(dispensation.getPatientId()));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<DispensationResponse> listDispensations(Integer patientId,
                                                                int page, int size) {
        Page<PharmacyDispensation> result = dispensationRepository
                .findByPatientIdOrderByDispensedDateDesc(patientId, PageRequest.of(page, size));

        Map<Integer, String> patients =
                names.patientNames(result.getContent(), PharmacyDispensation::getPatientId);

        var content = result.getContent().stream()
                .map(d -> mapper.toDispensationResponse(d, patients.get(d.getPatientId())))
                .toList();

        return new PageResponse<>(content, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }

    @Override
    @Transactional(readOnly = true)
    public List<InventoryBatchResponse> expiringWithin(int days) {
        LocalDate cutoff = LocalDate.now().plusDays(days);
        List<InventoryBatch> batches =
                batchRepository.findByExpiryDateLessThanEqualOrderByExpiryDate(cutoff);

        Map<Integer, String> medicines = medicineRepository
                .findAllById(batches.stream().map(InventoryBatch::getMedicineId).distinct().toList())
                .stream().collect(Collectors.toMap(Medicine::getMedicineId,
                        Medicine::getMedicineName, (a, b) -> a));

        return batches.stream()
                .map(b -> mapper.toBatchResponse(b, medicines.get(b.getMedicineId())))
                .toList();
    }

    private String medicineName(Integer medicineId) {
        return medicineRepository.findById(medicineId)
                .map(Medicine::getMedicineName)
                .orElse(null);
    }
}
