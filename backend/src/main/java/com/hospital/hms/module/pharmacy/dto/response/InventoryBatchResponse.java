package com.hospital.hms.module.pharmacy.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public record InventoryBatchResponse(
        Integer batchId,
        Integer medicineId,
        String medicineName,
        String batchNumber,
        Integer quantityReceived,
        Integer quantityAvailable,
        LocalDate manufactureDate,
        LocalDate expiryDate,
        String supplierName,
        BigDecimal purchasePrice,
        LocalDate receivedDate,
        Long daysToExpiry) {
}
