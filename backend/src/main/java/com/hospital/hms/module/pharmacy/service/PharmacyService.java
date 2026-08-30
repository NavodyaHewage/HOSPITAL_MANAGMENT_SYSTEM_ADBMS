package com.hospital.hms.module.pharmacy.service;

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
import java.util.List;

public interface PharmacyService {

    PageResponse<MedicineResponse> searchMedicines(String term, String category, int page, int size);

    MedicineResponse getMedicine(Integer medicineId);

    InventoryBatchResponse receiveStock(ReceiveStockRequest request, String performedBy);

    DispensationResponse dispense(DispenseRequest request, String dispensedBy);

    void adjustStock(StockAdjustmentRequest request, String performedBy);

    InventoryBatchResponse getBatch(Integer batchId);

    List<InventoryBatchResponse> listUsableBatches(Integer medicineId);

    List<CurrentMedicineStockView> currentStock(boolean onlyReorder);

    List<ExpiringBatchView> expiringBatches();

    List<DispensingHistoryView> dispensingHistory(Integer patientId, int limit);

    DispensationResponse getDispensation(Integer dispensationId);

    PageResponse<DispensationResponse> listDispensations(Integer patientId, int page, int size);

    List<InventoryBatchResponse> expiringWithin(int days);
}
