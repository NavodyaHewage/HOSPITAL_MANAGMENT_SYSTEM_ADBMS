package com.hospital.hms.module.prescription.mapper;

import com.hospital.hms.module.prescription.dto.response.PrescriptionItemResponse;
import com.hospital.hms.module.prescription.dto.response.PrescriptionResponse;
import com.hospital.hms.module.prescription.entity.Prescription;
import com.hospital.hms.module.prescription.entity.PrescriptionItem;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;

@Component
public class PrescriptionMapper {

    public PrescriptionItemResponse toItemResponse(PrescriptionItem item, String medicineName) {
        return new PrescriptionItemResponse(
                item.getItemId(),
                item.getMedicineId(),
                medicineName,
                item.getDosage(),
                item.getFrequency(),
                item.getDurationDays(),
                item.getQuantity(),
                item.getInstructions());
    }

    public PrescriptionResponse toResponse(Prescription p,
                                           String patientName,
                                           String doctorName,
                                           List<PrescriptionItem> items,
                                           Map<Integer, String> medicineNames,
                                           Integer distinctMedicines,
                                           Integer totalUnits) {
        List<PrescriptionItemResponse> itemResponses = items.stream()
                .map(item -> toItemResponse(item, medicineNames.get(item.getMedicineId())))
                .toList();

        return new PrescriptionResponse(
                p.getPrescriptionId(),
                p.getConsultationId(),
                p.getAppointmentId(),
                p.getPatientId(),
                patientName,
                p.getDoctorId(),
                doctorName,
                p.getPrescriptionDate(),
                p.getStatus() == null ? null : p.getStatus().name(),
                p.getNotes(),
                distinctMedicines,
                totalUnits,
                itemResponses);
    }
}
