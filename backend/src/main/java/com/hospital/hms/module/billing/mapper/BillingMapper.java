package com.hospital.hms.module.billing.mapper;

import com.hospital.hms.module.billing.dto.response.BillItemResponse;
import com.hospital.hms.module.billing.dto.response.BillResponse;
import com.hospital.hms.module.billing.dto.response.PaymentResponse;
import com.hospital.hms.module.billing.dto.response.ServiceResponse;
import com.hospital.hms.module.billing.entity.Bill;
import com.hospital.hms.module.billing.entity.BillItem;
import com.hospital.hms.module.billing.entity.Payment;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;

@Component
public class BillingMapper {

    public ServiceResponse toServiceResponse(com.hospital.hms.module.billing.entity.Service s) {
        return new ServiceResponse(
                s.getServiceId(),
                s.getServiceName(),
                s.getServiceCategory(),
                s.getDescription(),
                s.getPrice(),
                s.getIsActive());
    }

    public BillItemResponse toItemResponse(BillItem i, String serviceName) {
        return new BillItemResponse(
                i.getBillItemId(),
                i.getServiceId(),
                serviceName,
                i.getDescription(),
                i.getQuantity(),
                i.getUnitPrice(),
                i.getAmount());
    }

    public PaymentResponse toPaymentResponse(Payment p) {
        return new PaymentResponse(
                p.getPaymentId(),
                p.getBillId(),
                p.getPaymentDate(),
                p.getAmount(),
                p.getPaymentMethod() == null ? null : p.getPaymentMethod().dbValue(),
                p.getReferenceNumber(),
                p.getReceivedBy(),
                p.getNotes());
    }

    public BillResponse toBillResponse(Bill b, String patientName,
                                       List<BillItem> items, Map<Integer, String> serviceNames,
                                       List<Payment> payments, BigDecimal insuranceCover) {
        return new BillResponse(
                b.getBillId(),
                b.getPatientId(),
                patientName,
                b.getAppointmentId(),
                b.getBillDate(),
                b.getSubtotal(),
                b.getDiscount(),
                b.getTax(),
                b.getTotalAmount(),
                b.getPaidAmount(),
                b.getBalanceAmount(),
                b.getStatus() == null ? null : b.getStatus().name(),
                b.getRowVersion(),
                insuranceCover,
                items.stream().map(i -> toItemResponse(i, serviceNames.get(i.getServiceId()))).toList(),
                payments.stream().map(this::toPaymentResponse).toList());
    }
}
