package com.hospital.hms.module.billing.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.billing.dto.request.BillRequest;
import com.hospital.hms.module.billing.dto.request.PaymentRequest;
import com.hospital.hms.module.billing.dto.response.BillResponse;
import com.hospital.hms.module.billing.dto.response.PaymentOutcome;
import com.hospital.hms.module.billing.dto.response.ServiceResponse;
import com.hospital.hms.module.billing.repository.view.OutstandingBillView;
import com.hospital.hms.module.billing.repository.view.PatientBillingSummaryView;
import com.hospital.hms.module.billing.repository.view.PaymentHistoryView;
import com.hospital.hms.module.billing.service.BillingService;
import jakarta.validation.Valid;
import java.math.BigDecimal;
import java.security.Principal;
import java.util.List;
import java.util.Map;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/billing")
public class BillingController {

    private final BillingService billingService;

    public BillingController(BillingService billingService) {
        this.billingService = billingService;
    }

    @GetMapping("/services")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<List<ServiceResponse>> listServices() {
        return ApiResponse.ok(billingService.listServices());
    }

    /** Prices come from the services master, not from the request. */
    @PostMapping("/bills")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).BILL_CREATE)")
    public ApiResponse<BillResponse> createBill(@Valid @RequestBody BillRequest request) {
        return ApiResponse.ok("Bill created", billingService.createBill(request));
    }

    @GetMapping("/bills/{id}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<BillResponse> getBill(@PathVariable Integer id) {
        return ApiResponse.ok(billingService.getBill(id));
    }

    @GetMapping("/bills/by-patient/{patientId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PageResponse<BillResponse>> listByPatient(
            @PathVariable Integer patientId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(billingService.listByPatient(patientId, page, size));
    }

    @GetMapping("/bills/unpaid")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PAYMENT_RECORD)")
    public ApiResponse<PageResponse<BillResponse>> listUnpaid(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(billingService.listUnpaid(page, size));
    }

    /**
     * Overpaying returns HTTP 409 with the message from
     * trg_payments_bi_validate - the bill is never left inconsistent.
     */
    @PostMapping("/bills/{id}/payments")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PAYMENT_RECORD)")
    public ApiResponse<BillResponse> recordPayment(@PathVariable Integer id,
                                                   @Valid @RequestBody PaymentRequest request,
                                                   Principal principal) {
        return ApiResponse.ok("Payment recorded",
                billingService.recordPayment(id, request, principal.getName()));
    }

    /**
     * The full settlement path - locks the bill, optionally applies insurance
     * behind a SAVEPOINT, then commits. Returns the derived status and balance.
     */
    @PostMapping("/bills/{id}/settle")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PAYMENT_RECORD)")
    public ApiResponse<PaymentOutcome> settle(@PathVariable Integer id,
                                              @Valid @RequestBody PaymentRequest request,
                                              Principal principal) {
        return ApiResponse.ok("Bill settled",
                billingService.settleBill(id, request, principal.getName()));
    }

    /** Backed by vw_outstanding_bills - the debtors list. */
    @GetMapping("/outstanding")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PAYMENT_RECORD)")
    public ApiResponse<List<OutstandingBillView>> outstanding(
            @RequestParam(defaultValue = "100") int limit) {
        return ApiResponse.ok(billingService.outstandingBills(limit));
    }

    /** Backed by vw_payment_history. */
    @GetMapping("/payments")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PAYMENT_RECORD)")
    public ApiResponse<List<PaymentHistoryView>> paymentHistory(
            @RequestParam(required = false) Integer patientId,
            @RequestParam(defaultValue = "100") int limit) {
        return ApiResponse.ok(billingService.paymentHistory(patientId, limit));
    }

    /** Backed by vw_patient_billing_summary. */
    @GetMapping("/summary/{patientId}")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PATIENT_READ)")
    public ApiResponse<PatientBillingSummaryView> summary(@PathVariable Integer patientId) {
        return ApiResponse.ok(billingService.billingSummary(patientId));
    }

    /** Backed by fn_calculate_insurance_covered_amount. */
    @GetMapping("/bills/{id}/insurance-cover")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PAYMENT_RECORD)")
    public ApiResponse<Map<String, BigDecimal>> insuranceCover(@PathVariable Integer id) {
        return ApiResponse.ok(Map.of(
                "covered", billingService.insuranceCover(id),
                "balance", billingService.outstandingBalance(id)));
    }
}
