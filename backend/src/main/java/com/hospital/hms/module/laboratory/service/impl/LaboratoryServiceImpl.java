package com.hospital.hms.module.laboratory.service.impl;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.common.exception.BusinessRuleException;
import com.hospital.hms.common.exception.ResourceNotFoundException;
import com.hospital.hms.common.support.NameResolver;
import com.hospital.hms.module.laboratory.dto.request.LabOrderRequest;
import com.hospital.hms.module.laboratory.dto.request.LabResultRequest;
import com.hospital.hms.module.laboratory.dto.response.LabOrderResponse;
import com.hospital.hms.module.laboratory.dto.response.LabResultResponse;
import com.hospital.hms.module.laboratory.dto.response.LabTestResponse;
import com.hospital.hms.module.laboratory.entity.LabOrder;
import com.hospital.hms.module.laboratory.entity.LabOrderStatus;
import com.hospital.hms.module.laboratory.entity.LabResult;
import com.hospital.hms.module.laboratory.entity.LabTest;
import com.hospital.hms.module.laboratory.mapper.LaboratoryMapper;
import com.hospital.hms.module.laboratory.repository.LabOrderRepository;
import com.hospital.hms.module.laboratory.repository.LabResultRepository;
import com.hospital.hms.module.laboratory.repository.LabTestRepository;
import com.hospital.hms.module.laboratory.repository.procedure.LabProcedureRepository;
import com.hospital.hms.module.laboratory.repository.view.LabViewRepository;
import com.hospital.hms.module.laboratory.repository.view.PendingLabWorkView;
import com.hospital.hms.module.laboratory.service.LaboratoryService;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LaboratoryServiceImpl implements LaboratoryService {

    private final LabTestRepository testRepository;
    private final LabOrderRepository orderRepository;
    private final LabResultRepository resultRepository;
    private final LabProcedureRepository procedureRepository;
    private final LabViewRepository viewRepository;
    private final NameResolver names;
    private final LaboratoryMapper mapper;

    public LaboratoryServiceImpl(LabTestRepository testRepository,
                                 LabOrderRepository orderRepository,
                                 LabResultRepository resultRepository,
                                 LabProcedureRepository procedureRepository,
                                 LabViewRepository viewRepository,
                                 NameResolver names,
                                 LaboratoryMapper mapper) {
        this.testRepository = testRepository;
        this.orderRepository = orderRepository;
        this.resultRepository = resultRepository;
        this.procedureRepository = procedureRepository;
        this.viewRepository = viewRepository;
        this.names = names;
        this.mapper = mapper;
    }

    @Override
    @Transactional(readOnly = true)
    public List<LabTestResponse> listTests() {
        return testRepository.findAllByIsActiveTrueOrderByTestName().stream()
                .map(mapper::toTestResponse)
                .toList();
    }

    /** No @Transactional - the procedure owns its transaction. */
    @Override
    public LabOrderResponse placeOrder(LabOrderRequest request) {
        Integer orderId = procedureRepository.createOrderWorkflow(request);
        return getOrder(orderId);
    }

    /**
     * Records a result against an existing order. The insert alone is enough:
     * trg_lab_result_ai_close moves the order to Completed, and UNIQUE(order_id)
     * stops a second technician recording a duplicate.
     */
    @Override
    @Transactional
    public LabOrderResponse recordResult(Integer orderId, LabResultRequest request) {
        LabOrder order = findOrder(orderId);

        if (order.getStatus() == LabOrderStatus.CANCELLED) {
            throw new BusinessRuleException("Cannot record a result against a cancelled order");
        }
        if (resultRepository.existsByOrderId(orderId)) {
            throw new BusinessRuleException(
                    "A result has already been recorded for order " + orderId);
        }

        LabResult result = LabResult.builder()
                .orderId(orderId)
                .resultValue(request.resultValue())
                .performedBy(request.performedBy())
                .remarks(request.remarks())
                .isAbnormal(Boolean.TRUE.equals(request.isAbnormal()))
                .build();
        resultRepository.saveAndFlush(result);

        return getOrder(orderId);
    }

    @Override
    @Transactional(readOnly = true)
    public LabOrderResponse getOrder(Integer orderId) {
        LabOrder order = findOrder(orderId);
        LabTest test = testRepository.findById(order.getTestId()).orElse(null);
        LabResult result = resultRepository.findByOrderId(orderId).orElse(null);

        return mapper.toOrderResponse(order, test,
                names.patientName(order.getPatientId()),
                names.doctorName(order.getDoctorId()),
                result);
    }

    @Override
    @Transactional(readOnly = true)
    public List<LabOrderResponse> listByAppointment(Integer appointmentId) {
        return hydrate(orderRepository.findByAppointmentId(appointmentId));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<LabOrderResponse> listByPatient(Integer patientId, int page, int size) {
        return toPage(orderRepository.findByPatientIdOrderByOrderDateDesc(
                patientId, PageRequest.of(page, size)));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<LabOrderResponse> listByStatus(String status, int page, int size) {
        return toPage(orderRepository.findByStatusOrderByPriorityAscOrderDateAsc(
                LabOrderStatus.from(status), PageRequest.of(page, size)));
    }

    @Override
    @Transactional(readOnly = true)
    public List<PendingLabWorkView> pendingWorklist(int limit) {
        return viewRepository.findPendingWork(limit);
    }

    @Override
    @Transactional(readOnly = true)
    public int pendingCountForPatient(Integer patientId) {
        return procedureRepository.pendingCountForPatient(patientId);
    }

    @Override
    @Transactional
    public LabOrderResponse updateStatus(Integer orderId, String status) {
        LabOrder order = findOrder(orderId);
        LabOrderStatus target = LabOrderStatus.from(status);

        // Completed is the trigger's to set, not ours - a result is what
        // completes an order, so allowing it here would let the status say
        // "done" with no result behind it.
        if (target == LabOrderStatus.COMPLETED) {
            throw new BusinessRuleException(
                    "An order is completed by recording its result, not by setting the status");
        }
        order.setStatus(target);
        orderRepository.saveAndFlush(order);
        return getOrder(orderId);
    }

    private LabOrder findOrder(Integer orderId) {
        return orderRepository.findById(orderId)
                .orElseThrow(() -> new ResourceNotFoundException("Lab order", orderId));
    }

    private PageResponse<LabOrderResponse> toPage(Page<LabOrder> page) {
        List<LabOrderResponse> content = hydrate(page.getContent());
        return new PageResponse<>(content, page.getNumber(), page.getSize(),
                page.getTotalElements(), page.getTotalPages());
    }

    /** Resolves tests, names and results for a batch of orders in a few queries. */
    private List<LabOrderResponse> hydrate(List<LabOrder> orders) {
        if (orders.isEmpty()) {
            return List.of();
        }
        Map<Integer, LabTest> tests = testRepository
                .findAllById(orders.stream().map(LabOrder::getTestId).distinct().toList())
                .stream().collect(Collectors.toMap(LabTest::getTestId, t -> t));

        Map<Integer, LabResult> results = resultRepository
                .findByOrderIdIn(orders.stream().map(LabOrder::getOrderId).toList())
                .stream().collect(Collectors.toMap(LabResult::getOrderId, r -> r, (a, b) -> a));

        Map<Integer, String> patients = names.patientNames(orders, LabOrder::getPatientId);
        Map<Integer, String> doctors = names.doctorNames(orders, LabOrder::getDoctorId);

        return orders.stream()
                .map(o -> mapper.toOrderResponse(o, tests.get(o.getTestId()),
                        patients.get(o.getPatientId()), doctors.get(o.getDoctorId()),
                        results.get(o.getOrderId())))
                .toList();
    }

    /** Exposed for tests and for the order response assembly. */
    LabResultResponse toResultResponse(LabResult result) {
        return mapper.toResultResponse(result);
    }
}
