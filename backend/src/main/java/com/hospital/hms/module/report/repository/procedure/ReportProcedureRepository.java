package com.hospital.hms.module.report.repository.procedure;

import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import java.util.Map;
import org.springframework.stereotype.Repository;

/** Wraps sp_refresh_monthly_revenue. */
@Repository
public class ReportProcedureRepository {

    private static final String SP_REFRESH_MONTHLY_REVENUE = "sp_refresh_monthly_revenue";

    private final StoredProcedureExecutor executor;

    public ReportProcedureRepository(StoredProcedureExecutor executor) {
        this.executor = executor;
    }

    /** ymKey is 'YYYY-MM'. Deletes and rebuilds that month in one transaction. */
    public void refreshMonth(String ymKey) {
        executor.call(SP_REFRESH_MONTHLY_REVENUE, Map.of("p_ym", ymKey));
    }
}
