package com.hospital.hms.module.audit.service.impl;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.audit.dto.response.AuditLogResponse;
import com.hospital.hms.module.audit.dto.response.AuditReportRow;
import com.hospital.hms.module.audit.entity.AuditAction;
import com.hospital.hms.module.audit.entity.AuditLog;
import com.hospital.hms.module.audit.mapper.AuditMapper;
import com.hospital.hms.module.audit.repository.AuditLogRepository;
import com.hospital.hms.module.audit.repository.procedure.AuditProcedureRepository;
import com.hospital.hms.module.audit.repository.view.AuditViewRepository;
import com.hospital.hms.module.audit.repository.view.RecentAuditActivityView;
import com.hospital.hms.module.audit.service.AuditService;
import com.hospital.hms.module.auth.entity.User;
import com.hospital.hms.module.auth.repository.UserRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuditServiceImpl implements AuditService {

    private final AuditLogRepository auditLogRepository;
    private final AuditProcedureRepository procedureRepository;
    private final AuditViewRepository viewRepository;
    private final UserRepository userRepository;
    private final AuditMapper mapper;

    public AuditServiceImpl(AuditLogRepository auditLogRepository,
                            AuditProcedureRepository procedureRepository,
                            AuditViewRepository viewRepository,
                            UserRepository userRepository,
                            AuditMapper mapper) {
        this.auditLogRepository = auditLogRepository;
        this.procedureRepository = procedureRepository;
        this.viewRepository = viewRepository;
        this.userRepository = userRepository;
        this.mapper = mapper;
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<AuditLogResponse> search(String entityName, String action, Integer userId,
                                                 LocalDateTime from, LocalDateTime to,
                                                 int page, int size) {
        var pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
        return toPage(auditLogRepository.search(entityName,
                action == null ? null : AuditAction.valueOf(action),
                userId, from, to, pageable));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<AuditLogResponse> trailFor(String entityName, Integer entityId,
                                                   int page, int size) {
        return toPage(auditLogRepository.findByEntityNameAndEntityIdOrderByCreatedAtDesc(
                entityName, entityId, PageRequest.of(page, size)));
    }

    @Override
    @Transactional(readOnly = true)
    public List<RecentAuditActivityView> recentActivity(int limit) {
        return viewRepository.findRecent(limit);
    }

    @Override
    @Transactional(readOnly = true)
    public List<AuditReportRow> report(LocalDateTime from, LocalDateTime to, String entityName) {
        return procedureRepository.generateReport(from, to, entityName);
    }

    @Override
    @Transactional(readOnly = true)
    public int countEvents(String entityName, LocalDateTime from, LocalDateTime to) {
        return procedureRepository.countEvents(entityName, from, to);
    }

    @Override
    @Transactional(readOnly = true)
    public String activitySummary(Integer userId) {
        return procedureRepository.activitySummary(userId);
    }

    private PageResponse<AuditLogResponse> toPage(Page<AuditLog> page) {
        // audit_logs stores user_id only; resolve the whole page's usernames in
        // one query rather than joining per row.
        List<Integer> userIds = page.getContent().stream()
                .map(AuditLog::getUserId).filter(java.util.Objects::nonNull).distinct().toList();

        Map<Integer, String> usernames = userIds.isEmpty() ? Map.of()
                : userRepository.findAllById(userIds).stream()
                        .collect(Collectors.toMap(User::getUserId, User::getUsername, (a, b) -> a));

        var content = page.getContent().stream()
                .map(log -> mapper.toResponse(log, usernames.get(log.getUserId())))
                .toList();

        return new PageResponse<>(content, page.getNumber(), page.getSize(),
                page.getTotalElements(), page.getTotalPages());
    }
}
