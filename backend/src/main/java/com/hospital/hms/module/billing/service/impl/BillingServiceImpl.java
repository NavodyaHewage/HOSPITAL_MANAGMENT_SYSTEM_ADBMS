package com.hospital.hms.module.billing.service.impl;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.common.exception.ResourceNotFoundException;
import com.hospital.hms.common.support.NameResolver;
import com.hospital.hms.module.billing.dto.request.BillRequest;
import com.hospital.hms.module.billing.dto.request.PaymentRequest;
import com.hospital.hms.module.billing.dto.response.BillResponse;
import com.hospital.hms.module.billing.dto.response.PaymentOutcome;
import com.hospital.hms.module.billing.dto.response.ServiceResponse;
import com.hospital.hms.module.billing.entity.Bill;
import com.hospital.hms.module.billing.entity.BillItem;
import com.hospital.hms.module.billing.entity.BillStatus;
import com.hospital.hms.module.billing.entity.Payment;
import com.hospital.hms.module.billing.mapper.BillingMapper;
import com.hospital.hms.module.billing.repository.BillItemRepository;
import com.hospital.hms.module.billing.repository.BillRepository;
import com.hospital.hms.module.billing.repository.PaymentRepository;
import com.hospital.hms.module.billing.repository.ServiceRepository;
import com.hospital.hms.module.billing.repository.procedure.BillingProcedureRepository;
import com.hospital.hms.module.billing.repository.view.BillingViewRepository;
import com.hospital.hms.module.billing.repository.view.OutstandingBillView;
import com.hospital.hms.module.billing.repository.view.PatientBillingSummaryView;
import com.hospital.hms.module.billing.repository.view.PaymentHistoryView;
import com.hospital.hms.module.billing.service.BillingService;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BillingServiceImpl implements BillingService {

    private final BillRepository billRepository;
    private final BillItemRepository billItemRepository;
    private final PaymentRepository paymentRepository;
    private final ServiceRepository serviceRepository;
    private final BillingProcedureRepository procedureRepository;
    private final BillingViewRepository viewRepository;
    private final NameResolver names;
    private final BillingMapper mapper;

    public BillingServiceImpl(BillRepository billRepository,
                              BillItemRepository billItemRepository,
                              PaymentRepository paymentRepository,
                              ServiceRepository serviceRepository,
                              BillingProcedureRepository procedureRepository,
                              BillingViewRepository viewRepository,
                              NameResolver names,
                              BillingMapper mapper) {
        this.billRepository = billRepository;
        this.billItemRepository = billItemRepository;
        this.paymentRepository = paymentRepository;
        this.serviceRepository = serviceRepository;
        this.procedureRepository = procedureRepository;
        this.viewRepository = viewRepository;
        this.names = names;
        this.mapper = mapper;
    }

    @Override
    @Transactional(readOnly = true)
    public List<ServiceResponse> listServices() {
        return serviceRepository.findAllByIsActiveTrueOrderByServiceName().stream()
                .map(mapper::toServiceResponse)
                .toList();
    }

    /** No @Transactional - sp_create_bill_with_items owns its transaction. */
    @Override
    public BillResponse createBill(BillRequest request) {
        Integer billId = procedureRepository.createBillWithItems(request);
        return getBill(billId);
    }

    /**
     * Records a payment. Routing depends on whether insurance should be tried:
     * the full procedure locks the bill and runs the SAVEPOINT branch, while the
     * thin one is enough for a plain cash payment. Either way the bill totals
     * are derived by trg_payments_ai_apply, never written here.
     */
    @Override
    public BillResponse recordPayment(Integer billId, PaymentRequest request, String receivedBy) {
        if (Boolean.TRUE.equals(request.applyInsurance())) {
            procedureRepository.processCompletePayment(billId, request, true, receivedBy);
        } else {
            procedureRepository.recordPayment(billId, request, receivedBy);
        }
        return getBill(billId);
    }

    @Override
    public PaymentOutcome settleBill(Integer billId, PaymentRequest request, String receivedBy) {
        return procedureRepository.processCompletePayment(
                billId, request, Boolean.TRUE.equals(request.applyInsurance()), receivedBy);
    }

    @Override
    @Transactional(readOnly = true)
    public BillResponse getBill(Integer billId) {
        Bill bill = billRepository.findById(billId)
                .orElseThrow(() -> new ResourceNotFoundException("Bill", billId));

        List<BillItem> items = billItemRepository.findByBillId(billId);
        List<Payment> payments = paymentRepository.findByBillIdOrderByPaymentDate(billId);

        return mapper.toBillResponse(bill,
                names.patientName(bill.getPatientId()),
                items,
                serviceNames(items),
                payments,
                procedureRepository.insuranceCoveredAmount(billId));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<BillResponse> listByPatient(Integer patientId, int page, int size) {
        return toPage(billRepository.findByPatientIdOrderByBillDateDesc(
                patientId, PageRequest.of(page, size)));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<BillResponse> listUnpaid(int page, int size) {
        return toPage(billRepository.findByStatusInOrderByBillDateDesc(
                List.of(BillStatus.Pending, BillStatus.Partial), PageRequest.of(page, size)));
    }

    @Override
    @Transactional(readOnly = true)
    public List<OutstandingBillView> outstandingBills(int limit) {
        return viewRepository.findOutstanding(limit);
    }

    @Override
    @Transactional(readOnly = true)
    public List<PaymentHistoryView> paymentHistory(Integer patientId, int limit) {
        return viewRepository.findPaymentHistory(patientId, limit);
    }

    @Override
    @Transactional(readOnly = true)
    public PatientBillingSummaryView billingSummary(Integer patientId) {
        return viewRepository.findBillingSummary(patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Billing summary for patient", patientId));
    }

    @Override
    @Transactional(readOnly = true)
    public BigDecimal insuranceCover(Integer billId) {
        return procedureRepository.insuranceCoveredAmount(billId);
    }

    @Override
    @Transactional(readOnly = true)
    public BigDecimal outstandingBalance(Integer billId) {
        return procedureRepository.billBalance(billId);
    }

    /**
     * Listing pages carry headers only - no items or payments. Loading both for
     * every row would be two extra queries per bill, and a list screen shows
     * totals, not line detail. Callers open a single bill for that.
     */
    private PageResponse<BillResponse> toPage(Page<Bill> page) {
        Map<Integer, String> patients = names.patientNames(page.getContent(), Bill::getPatientId);

        var content = page.getContent().stream()
                .map(b -> mapper.toBillResponse(b, patients.get(b.getPatientId()),
                        List.of(), Map.of(), List.of(), null))
                .toList();

        return new PageResponse<>(content, page.getNumber(), page.getSize(),
                page.getTotalElements(), page.getTotalPages());
    }

    private Map<Integer, String> serviceNames(List<BillItem> items) {
        List<Integer> ids = items.stream().map(BillItem::getServiceId).distinct().toList();
        if (ids.isEmpty()) {
            return Map.of();
        }
        return serviceRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(
                        com.hospital.hms.module.billing.entity.Service::getServiceId,
                        com.hospital.hms.module.billing.entity.Service::getServiceName,
                        (a, b) -> a));
    }
}
