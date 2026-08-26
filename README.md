# Hospital Management System — ADBMS Project

Full-stack application over the `hospital_management` MySQL schema.

| Layer    | Stack                                                        |
|----------|--------------------------------------------------------------|
| Database | MySQL 8 — 24 tables, 15 functions, 15 views, 16 procedures, 15 triggers |
| Backend  | Spring Boot 3.3 (Java 17), Spring Data JPA + JdbcTemplate, Spring Security + JWT |
| Frontend | React 18 + Vite, React Router, TanStack Query, Axios          |

## Layout

```
HOSPITAL_MANAGMENT_SYSTEM_ADBMS/
├── backend/          Spring Boot API  (see backend/README.md)
├── frontend/         React SPA        (see frontend/README.md)
├── database/         SQL scripts      (see database/README.md)
├── docs/             ER diagram, API notes, screenshots
├── scripts/          database load helpers
└── .github/workflows CI
```

## Running it

1. **Database**

   ```bash
   mysql -u root -p < database/99_COMPLETE_HOSPITAL_DB.sql
   ```

   or rebuild layer by layer with `scripts/load-database.ps1`.

2. **Backend** — copy `backend/.env.example` values into your environment, then:

   ```bash
   cd backend && ./mvnw spring-boot:run
   ```

   API on `http://localhost:8080/api`, Swagger UI at `/api/swagger-ui.html`.

3. **Frontend**

   ```bash
   cd frontend && npm install && npm run dev
   ```

   App on `http://localhost:5173`, proxying `/api` to the backend.

## Design rules

- **The database owns the business rules.** Booking, dispensing, billing and
  payment logic already lives in stored procedures and triggers. The backend
  calls them rather than reimplementing them; `ddl-auto` is `validate`.
- **Errors flow through.** A procedure raising SQLSTATE 45000 becomes a
  `BusinessRuleException` and then HTTP 409 carrying the message the procedure
  itself wrote, which the React layer shows verbatim.
- **RBAC is data-driven.** The seven roles and their permissions come from
  `roles` / `permissions` / `role_permissions`. JWT claims carry the resolved
  permission names; the backend checks them with `@PreAuthorize` and the
  frontend hides navigation with the same names.
