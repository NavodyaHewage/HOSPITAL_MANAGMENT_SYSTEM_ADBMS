# Database

`99_COMPLETE_HOSPITAL_DB.sql` is the master build script. The folders below are
that same script split along its original file boundaries, so you can rebuild a
single layer without re-running everything.

## Load order

```
schema/01_schema.sql          DDL: 24 tables, generated columns, indexes
seed/02_seed_data.sql         reference + demo data, ANALYZE TABLE
functions/03_functions.sql    15 stored functions (fn_*)
views/04_views.sql            15 views (vw_*)
procedures/05_procedures.sql  16 procedures (sp_*)
triggers/06_triggers.sql      15 triggers (trg_*)
```

`demos/` holds the coursework demonstration scripts (transactions, file
organisation and indexing, view serializability). Run those block by block,
not as whole files.

## Contract with the backend

- Hibernate is set to `ddl-auto: validate`. The schema is owned here; entity
  classes must follow it, never the other way round.
- Every write path that has a procedure goes through that procedure. The
  procedures own their own `START TRANSACTION`/`COMMIT` and raise
  `SQLSTATE '45000'` with a readable message, which the backend maps to
  HTTP 409 via `BusinessRuleException`.
- Views are mapped as read-only projections, never as JPA entities.
