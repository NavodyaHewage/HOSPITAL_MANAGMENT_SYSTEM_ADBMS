# HMS Backend — API Reference

92 endpoints across 13 modules, over the `hospital_management` schema.
Interactive docs run at `http://localhost:8080/swagger-ui.html` while the app is up.

Base path is `/api`. Every response uses one envelope:

```json
{ "success": true, "message": "OK", "data": { }, "timestamp": "2026-08-29T20:39:21" }
```

## Authentication

`POST /api/auth/login` and `POST /api/auth/refresh` are the only anonymous
endpoints. Everything else needs `Authorization: Bearer <accessToken>`.

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user007","password":"Passw0rd!7"}'
```

Seeded accounts are `user001`–`user060` with password `Passw0rd!<n>` — so
`user007` is `Passw0rd!7`. Roles cycle as `1 + (n MOD 7)`, so `user007`,
`user014`, `user021` … are ADMIN. Accounts where `n MOD 20 = 0` are inactive
and cannot log in.

| Status | Meaning |
|---|---|
| 401 | No token, or it is invalid/expired — re-authenticate |
| 403 | Signed in, but the role lacks the permission |
| 409 | A database rule rejected it (see **Business rules** below) |

## Permissions

The 13 permission names come from the `permissions` table. `Permissions.java`
mirrors them and `PermissionsIntegrityTest` fails the build if the two drift —
a constant that does not exist in the table can never be granted, so an endpoint
guarding on it would silently deny everyone.

`PATIENT_READ` · `PATIENT_WRITE` · `APPOINTMENT_BOOK` · `CONSULT_WRITE` ·
`PRESCRIBE` · `LAB_ORDER` · `LAB_RESULT_WRITE` · `BILL_CREATE` ·
`PAYMENT_RECORD` · `STOCK_RECEIVE` · `STOCK_DISPENSE` · `AUDIT_READ` ·
`USER_MANAGE`

## Endpoints by module

### auth
| Method | Path | Permission |
|---|---|---|
| POST | `/auth/login` | anonymous |
| POST | `/auth/refresh` | anonymous |
| POST | `/auth/logout` | authenticated |
| GET | `/auth/me` | authenticated |

Login stamps `last_login`; logout stamps `last_logout`. Both fire
`trg_users_au_session`, which writes the LOGIN/LOGOUT rows into `audit_logs`.

### patients
`GET|POST /patients` · `GET /patients/{id}` · `DELETE /patients/{id}` (deactivates).
Writes go through `sp_register_or_update_patient`.

### departments · doctors
`GET /departments` · `GET /doctors` · `GET /doctors/{id}` ·
`GET /doctors/by-department/{id}` · `GET /doctors/availability` ·
`GET /doctors/{id}/slot-free`. Admin CRUD needs `USER_MANAGE`.

`/doctors/availability` is `sp_search_doctor_availability`; `/slot-free` is
`fn_check_doctor_availability` — a UI convenience only, **not** a booking
guarantee (another user can take the slot before your POST lands).

### appointments
`POST /appointments` books when `appointmentId` is null and reschedules when it
is set — one call, backed by `sp_book_or_reschedule_appointment`.
Also `GET /appointments`, `/upcoming`, `/schedule`, `/history/{patientId}`,
`/count/{patientId}`, `PATCH /{id}/status`, `DELETE /{id}` (cancels).

### consultations · prescriptions · lab
- `POST /consultations` → `sp_create_consultation`, which also flips the
  appointment to Completed.
- `POST /prescriptions` → `sp_create_prescription_with_items`; header and every
  line commit together or not at all.
- `POST /lab/orders` → `sp_create_lab_order_result_workflow`; supply
  `resultValue` to place the order and record the result in one transaction.
- `POST /lab/orders/{id}/result` records a result, which closes the order via
  `trg_lab_result_ai_close`. `GET /lab/worklist` is the Stat-first queue.

### pharmacy
`POST /pharmacy/stock/receive` · `POST /pharmacy/dispense` (FIFO/FEFO across
batches) · `POST /pharmacy/stock/adjust` · `GET /pharmacy/stock` ·
`GET /pharmacy/expiring` · `GET /pharmacy/medicines`.

Stock levels are never written by the API. Every movement is a
`stock_transactions` row and `trg_stock_tx_ai_apply` derives
`quantity_available`, so a batch cannot disagree with its own ledger.

### billing
`POST /billing/bills` · `POST /billing/bills/{id}/payments` ·
`POST /billing/bills/{id}/settle` · `GET /billing/outstanding` ·
`GET /billing/summary/{patientId}` · `GET /billing/payments`.

Bill line prices come from the `services` master, not the request — a client
cannot invent its own price. `paid_amount`, `balance_amount` and `status` are
derived by `trg_payments_ai_apply` from the payments table.

`/settle` runs `sp_process_complete_payment_transaction`: it X-locks the bill,
applies any insurance credit behind a SAVEPOINT (an invalid policy is undone
without losing the cash payment), refuses to overpay, then commits.

### audit · reports · users
`/audit/**` is read-only by design — audit rows are written by triggers inside
the transaction they describe, and an audit trail the application can rewrite is
not an audit trail. `/reports/monthly-revenue` reads the pre-aggregated
`monthly_revenue_summary`; POST `/refresh` rebuilds it via
`sp_refresh_monthly_revenue`. `/users/**` needs `USER_MANAGE`.

## Business rules (HTTP 409)

These messages come from the database, not from Java. `SIGNAL SQLSTATE '45000'`
is translated by `StoredProcedureExecutor` into a `BusinessRuleException`.

| Trigger / rule | Message |
|---|---|
| `uq_active_slot` + booking procedure | `Doctor is not available at that date/time` / `SLOT ALREADY BOOKED: …` |
| `trg_payments_bi_validate` | `Payment exceeds the outstanding balance of this bill` |
| `trg_inventory_bu_prevent_negative` | `STOCK CANNOT GO NEGATIVE: dispense rejected` |
| `sp_dispense_medicine` | `INSUFFICIENT STOCK: not enough unexpired quantity` |
| `trg_prescription_items_bi_validate` | `Prescription quantity must be greater than zero` |
| `trg_appointments_bu_validate` | `A completed appointment cannot be re-opened` |

## Architecture

Reads use JPA entities and repositories. **Writes that carry a business rule go
through the stored procedures** rather than being re-implemented in Java, so
there is exactly one copy of each rule and the concurrency demonstrations in
`database/demos/` describe the same code path the API uses.

Derived columns have a single owner. `bills.paid_amount`,
`inventory_batches.quantity_available` and `lab_orders.status` are owned by
triggers and are mapped read-only in the entities — a stray `save()` cannot
claim a bill was paid with no payment row behind it.

Procedures manage their own transactions, so the services that call them are
deliberately **not** `@Transactional`.
