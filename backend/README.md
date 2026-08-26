# Backend — Spring Boot

## Package layout

```
com.hospital.hms
├── HmsApplication.java
├── config/                CORS, OpenAPI, JPA auditing
├── security/              SecurityConfig, jwt/, rbac/ (permission + role names)
├── common/
│   ├── dto/               ApiResponse, PageResponse
│   ├── exception/         ResourceNotFoundException, BusinessRuleException, handler
│   ├── jdbc/              StoredProcedureExecutor (SQLSTATE 45000 translation)
│   ├── audit/             request auditing hooks
│   └── util/
└── module/<feature>/
    ├── controller/        REST endpoints
    ├── service/ + impl/   orchestration
    ├── repository/        JPA repositories (reads)
    │   ├── procedure/     SimpleJdbcCall wrappers (writes)
    │   └── view/          read-only projections over vw_*
    ├── entity/            JPA entities mapped to the existing tables
    ├── dto/request|response/
    └── mapper/
```

## Modules and the schema they cover

| Module | Tables | Key routines |
|--------|--------|--------------|
| `auth` | users, user_roles, role_permissions | login, refresh |
| `user` | users, roles, permissions | `sp_create_user_with_role`, `sp_assign_revoke_role_permission` |
| `patient` | patients | `sp_register_or_update_patient` |
| `department` | departments | — |
| `doctor` | doctors | `fn_check_doctor_availability` |
| `appointment` | appointments | `sp_book_or_reschedule_appointment`, `sp_search_doctor_availability` |
| `consultation` | consultations | `sp_create_consultation` |
| `prescription` | prescriptions, prescription_items | `sp_create_prescription_with_items` |
| `laboratory` | lab_tests, lab_orders, lab_results | `sp_create_lab_order_result_workflow` |
| `pharmacy` | medicines, inventory_batches, stock_transactions, pharmacy_dispensations | `sp_receive_medicine_stock`, `sp_dispense_medicine`, `sp_record_stock_adjustment` |
| `billing` | services, insurance_profiles, bills, bill_items, payments | `sp_create_bill_with_items`, `sp_record_payment`, `sp_process_complete_payment_transaction` |
| `audit` | audit_logs | `sp_generate_audit_report` |
| `report` | monthly_revenue_summary + all `vw_*` | `sp_refresh_monthly_revenue` |

`module/patient` is implemented end to end as the reference pattern — copy its
shape (entity, procedure repository, service, controller) for the rest.

## Conventions

- Writes that a procedure covers go through `repository/procedure/`. Do **not**
  put `@Transactional` around those calls: the procedures manage their own
  transactions.
- Reads that a view covers go through `repository/view/` as Spring Data
  projections.
- Controllers return `ApiResponse<T>` and nothing else.
- Method security uses permission names from `security/rbac/Permissions`, which
  mirror the seeded `permissions` table.
