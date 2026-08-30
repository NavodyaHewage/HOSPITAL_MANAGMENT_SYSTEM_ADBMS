package com.hospital.hms.module.pharmacy.dto.response;

import java.math.BigDecimal;

public record MedicineResponse(
        Integer medicineId,
        String medicineName,
        String genericName,
        String category,
        String manufacturer,
        String unitOfMeasure,
        Integer reorderLevel,
        BigDecimal unitPrice,
        Boolean isActive,
        Integer availableStock,
        Boolean needsReorder,
        BigDecimal stockValue) {
}
