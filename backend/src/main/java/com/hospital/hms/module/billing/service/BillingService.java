package com.hospital.hms.module.billing.service;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.billing.dto.request.BillRequest;
import com.hospital.hms.module.billing.dto.request.PaymentRequest;
import com.hospital.hms.module.billing.dto.response.BillResponse;
import com.hospital.hms.module.billing.dto.response.PaymentOutcome;
import com.hospital.hms.module.billing.dto.response.ServiceResponse;
import com.hospital.hms.module.billing.repository.view.OutstandingBillView;
import com.hospital.hms.module.billing.repository.view.PatientBillingSummaryView;
import com.hospital.hms.module.billing.repository.view.PaymentHistoryView;
import java.math.BigDecimal;
import java.util.List;

public interface BillingService {

    List<ServiceResponse> listServices();

    BillResponse createBill(BillRequest request);

    BillResponse recordPayment(Integer billId, PaymentRequest request, String receivedBy);

    PaymentOutcome settleBill(Integer billId, PaymentRequest request, String receivedBy);

    BillResponse getBill(Integer billId);

    PageResponse<BillResponse> listByPatient(Integer patientId, int page, int size);

    PageResponse<BillResponse> listUnpaid(int page, int size);

    List<OutstandingBillView> outstandingBills(int limit);

    List<PaymentHistoryView> paymentHistory(Integer patientId, int limit);

    PatientBillingSummaryView billingSummary(Integer patientId);

    BigDecimal insuranceCover(Integer billId);

    BigDecimal outstandingBalance(Integer billId);
}
