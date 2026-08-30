package com.hospital.hms.module.pharmacy.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.pharmacy.dto.request.DispenseRequest;
import com.hospital.hms.module.pharmacy.dto.request.ReceiveStockRequest;
import com.hospital.hms.module.pharmacy.dto.request.StockAdjustmentRequest;
import com.hospital.hms.module.pharmacy.dto.response.DispensationResponse;
import com.hospital.hms.module.pharmacy.dto.response.InventoryBatchResponse;
import com.hospital.hms.module.pharmacy.dto.response.MedicineResponse;
import com.hospital.hms.module.pharmacy.repository.view.CurrentMedicineStockView;
import com.hospital.hms.module.pharmacy.repository.view.DispensingHistoryView;
import com.hospital.hms.module.pharmacy.repository.view.ExpiringBatchView;
import com.hospital.hms.module.pharmacy.service.PharmacyService;
import jakarta.validation.Valid;
import java.security.Principal;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/pharmacy")
public class PharmacyController {

    private final PharmacyService pharmacyService;

    public PharmacyController(PharmacyService pharmacyService) {
        this.pharmacyService = pharmacyService;
    }

    @GetMapping("/medicines")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PageResponse<MedicineResponse>> searchMedicines(
            @RequestParam(required = false) String term,
            @RequestParam(required = false) String category,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(pharmacyService.searchMedicines(term, category, page, size));
    }

    @GetMapping("/medicines/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<MedicineResponse> getMedicine(@PathVariable Integer id) {
        return ApiResponse.ok(pharmacyService.getMedicine(id));
    }

    /** Goods received note - creates the batch and its opening ledger entry. */
    @PostMapping("/stock/receive")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).STOCK_RECEIVE)")
    public ApiResponse<InventoryBatchResponse> receiveStock(
            @Valid @RequestBody ReceiveStockRequest request, Principal principal) {
        return ApiResponse.ok("Stock received",
                pharmacyService.receiveStock(request, principal.getName()));
    }

    /**
     * FIFO dispense across batches. Insufficient stock comes back as HTTP 409
     * carrying "STOCK CANNOT GO NEGATIVE" from the trigger, and nothing is
     * written - not even the dispensation header.
     */
    @PostMapping("/dispense")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).STOCK_DISPENSE)")
    public ApiResponse<DispensationResponse> dispense(
            @Valid @RequestBody DispenseRequest request, Principal principal) {
        return ApiResponse.ok("Medicine dispensed",
                pharmacyService.dispense(request, principal.getName()));
    }

    @PostMapping("/stock/adjust")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).STOCK_RECEIVE)")
    public ApiResponse<Void> adjustStock(
            @Valid @RequestBody StockAdjustmentRequest request, Principal principal) {
        pharmacyService.adjustStock(request, principal.getName());
        return ApiResponse.ok("Stock adjusted", null);
    }

    @GetMapping("/batches/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).STOCK_RECEIVE)")
    public ApiResponse<InventoryBatchResponse> getBatch(@PathVariable Integer id) {
        return ApiResponse.ok(pharmacyService.getBatch(id));
    }

    /** Usable batches in FIFO order - the same order sp_dispense_medicine walks. */
    @GetMapping("/batches/usable/{medicineId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).STOCK_DISPENSE)")
    public ApiResponse<List<InventoryBatchResponse>> usableBatches(@PathVariable Integer medicineId) {
        return ApiResponse.ok(pharmacyService.listUsableBatches(medicineId));
    }

    /** Backed by vw_current_medicine_stock. */
    @GetMapping("/stock")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).STOCK_RECEIVE)")
    public ApiResponse<List<CurrentMedicineStockView>> currentStock(
            @RequestParam(defaultValue = "false") boolean onlyReorder) {
        return ApiResponse.ok(pharmacyService.currentStock(onlyReorder));
    }

    /** Backed by vw_expiring_batches - EXPIRED / CRITICAL / WATCH. */
    @GetMapping("/expiring")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).STOCK_RECEIVE)")
    public ApiResponse<List<ExpiringBatchView>> expiring() {
        return ApiResponse.ok(pharmacyService.expiringBatches());
    }

    @GetMapping("/dispensations/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).STOCK_DISPENSE)")
    public ApiResponse<DispensationResponse> getDispensation(@PathVariable Integer id) {
        return ApiResponse.ok(pharmacyService.getDispensation(id));
    }

    @GetMapping("/dispensations/by-patient/{patientId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).STOCK_DISPENSE)")
    public ApiResponse<PageResponse<DispensationResponse>> listDispensations(
            @PathVariable Integer patientId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(pharmacyService.listDispensations(patientId, page, size));
    }

    /** Backed by vw_dispensing_history. */
    @GetMapping("/dispensing-history")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).STOCK_DISPENSE)")
    public ApiResponse<List<DispensingHistoryView>> dispensingHistory(
            @RequestParam(required = false) Integer patientId,
            @RequestParam(defaultValue = "100") int limit) {
        return ApiResponse.ok(pharmacyService.dispensingHistory(patientId, limit));
    }
}
