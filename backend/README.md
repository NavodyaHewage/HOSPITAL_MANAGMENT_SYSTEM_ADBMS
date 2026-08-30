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

All 13 modules are implemented — 92 endpoints across 13 controllers.
`module/patient` remains the smallest example of the shape if you need a
reference when adding a fourteenth.

## Conventions

- Writes that a procedure covers go through `repository/procedure/`. Do **not**
  put `@Transactional` around those calls: the procedures manage their own
  transactions.
- Reads that a view covers go through `repository/view/` as Spring Data
  projections.
- Controllers return `ApiResponse<T>` and nothing else.
- Method security uses permission names from `security/rbac/Permissions`, which
  mirror the seeded `permissions` table. `PermissionsIntegrityTest` fails the
  build if they drift: a constant absent from the table can never be granted, so
  every endpoint guarding on it would silently deny all callers.
- Columns owned by a trigger (`bills.paid_amount`, `balance_amount`, `status`;
  `inventory_batches.quantity_available`) are mapped `insertable = false,
  updatable = false`. The trigger derives them from the ledger; Java must not
  write them.
- MySQL `ENUM` columns need `columnDefinition` on `@Column`, or
  `ddl-auto=validate` rejects them (`found [enum], but expecting [varchar]`).
  Three enums contain values that are not legal Java identifiers — `No-Show`,
  `In-Progress`, `Bank Transfer` — and are mapped through an `AttributeConverter`
  rather than `EnumType.STRING`, which would persist `NO_SHOW` and be rejected.
  `EnumMappingTest` pins the exact spellings.
- Passwords are SHA-256, not bcrypt, because the schema hashes them itself
  (`sp_create_user_with_role` uses `SHA2(p_password, 256)`). See
  `MysqlSha256PasswordEncoder` — the encoder has to agree with whoever writes
  the hash, and here that is the database.

## Running it

```bash
cd backend
./mvnw spring-boot:run
```

Needs the database built first (`database/99_COMPLETE_HOSPITAL_DB.sql`).
Connection settings come from `application.properties`, overridable with
`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `SERVER_PORT`, `JWT_SECRET`.

- API base path: `http://localhost:8080/api`
- Swagger UI: `http://localhost:8080/swagger-ui.html`
- Endpoint reference: [`docs/api/README.md`](../docs/api/README.md)

`ddl-auto=validate` is deliberate: the schema belongs to the scripts in
`database/`, and startup fails loudly if an entity drifts from it.

Log in with any seeded account — `user001`–`user060`, password `Passw0rd!<n>`.
`user007` is an ADMIN and holds all 13 permissions.
