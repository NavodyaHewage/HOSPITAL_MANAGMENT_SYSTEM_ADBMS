package com.hospital.hms.module.pharmacy.mapper;

import com.hospital.hms.module.pharmacy.dto.response.DispensationResponse;
import com.hospital.hms.module.pharmacy.dto.response.InventoryBatchResponse;
import com.hospital.hms.module.pharmacy.dto.response.MedicineResponse;
import com.hospital.hms.module.pharmacy.entity.InventoryBatch;
import com.hospital.hms.module.pharmacy.entity.Medicine;
import com.hospital.hms.module.pharmacy.entity.PharmacyDispensation;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import org.springframework.stereotype.Component;

@Component
public class PharmacyMapper {

    public MedicineResponse toMedicineResponse(Medicine m, Integer availableStock,
                                               Boolean needsReorder, BigDecimal stockValue) {
        return new MedicineResponse(
                m.getMedicineId(),
                m.getMedicineName(),
                m.getGenericName(),
                m.getCategory(),
                m.getManufacturer(),
                m.getUnitOfMeasure(),
                m.getReorderLevel(),
                m.getUnitPrice(),
                m.getIsActive(),
                availableStock,
                needsReorder,
                stockValue);
    }

    public InventoryBatchResponse toBatchResponse(InventoryBatch b, String medicineName) {
        Long daysToExpiry = b.getExpiryDate() == null
                ? null
                : ChronoUnit.DAYS.between(LocalDate.now(), b.getExpiryDate());

        return new InventoryBatchResponse(
                b.getBatchId(),
                b.getMedicineId(),
                medicineName,
                b.getBatchNumber(),
                b.getQuantityReceived(),
                b.getQuantityAvailable(),
                b.getManufactureDate(),
                b.getExpiryDate(),
                b.getSupplierName(),
                b.getPurchasePrice(),
                b.getReceivedDate(),
                daysToExpiry);
    }

    public DispensationResponse toDispensationResponse(PharmacyDispensation d, String patientName) {
        return new DispensationResponse(
                d.getDispensationId(),
                d.getPrescriptionId(),
                d.getPatientId(),
                patientName,
                d.getDispensedDate(),
                d.getDispensedBy(),
                d.getTotalItems(),
                d.getStatus() == null ? null : d.getStatus().name(),
                d.getNotes());
    }
}
