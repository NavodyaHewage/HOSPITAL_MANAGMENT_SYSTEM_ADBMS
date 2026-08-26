# API notes

Base URL: `http://localhost:8080/api`. Live contract: `/api/swagger-ui.html`.

Every response uses the envelope:

```json
{ "success": true, "message": "OK", "data": {}, "timestamp": "2026-01-01T10:00:00" }
```

## Status codes

| Code | Meaning |
|------|---------|
| 200  | OK |
| 400  | Bean-validation failure; `data` maps field to message |
| 401  | Missing or expired JWT |
| 403  | Authenticated but lacking the required permission |
| 404  | Row not found |
| 409  | Database rule rejected the write (SQLSTATE 45000) or a constraint was violated |

409 is the interesting one: its `message` is produced by the schema itself, for
example `SLOT ALREADY BOOKED: another user took this doctor/date/time`.
