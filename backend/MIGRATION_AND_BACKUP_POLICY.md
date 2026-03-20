# Backend Migration and Backup Policy

Last Updated: 2026-03-20
Owner: Dev A + Release
Scope: MongoDB schema/index migration and backup operations for GigCredit backend

## 1) Migration Policy

1. All runtime-required indexes are managed by application startup (`ensure_indexes` in backend app database module).
2. Backward-compatible collection fallbacks must be preserved during migration windows.
3. Any breaking collection/key migration must be executed in three steps:
- Step A: dual-write/read compatibility period
- Step B: backfill existing records
- Step C: remove legacy paths only after verification tests pass

## 2) Retention Policy

TTL index retention is enforced on log collections:
- verification_api_logs: 90 days (default)
- report_api_logs: 180 days (default)
- audit_traces: 30 days (default)

Configuration variables:
- VERIFICATION_LOG_RETENTION_DAYS
- REPORT_LOG_RETENTION_DAYS
- AUDIT_TRACE_RETENTION_DAYS

## 3) Backup Policy

1. Daily logical backup of production database.
2. Keep rolling 14-day backup history.
3. Keep one weekly backup for 8 weeks.
4. Keep one monthly backup for 6 months.

Recommended command pattern:

```bash
mongodump --uri "$MONGO_URI" --db "$MONGO_DB_NAME" --out ./backups/YYYY-MM-DD
```

Restore command pattern:

```bash
mongorestore --uri "$MONGO_URI" --db "$MONGO_DB_NAME" --drop ./backups/YYYY-MM-DD/$MONGO_DB_NAME
```

## 4) Recovery Drill

- Run one restore drill per release cycle in staging.
- Verify:
  - core verification records
  - report storage records
  - API log collections
- Record recovery time and integrity checks in release notes.

## 5) Evidence Requirements

For release signoff, attach:
- migration execution note (if any data move performed)
- latest successful backup log
- latest successful restore drill log
- backend contract smoke test output after migration/restore
