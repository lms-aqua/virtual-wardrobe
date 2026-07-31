# Runbook — database migrations & backup/restore

## Migrations (Alembic — the discipline)

The DB is versioned with Alembic (`apps/api/migrations`). **Do not wipe &
recreate** to apply schema changes anymore; write a migration.

Add a migration after changing models:
```bash
cd apps/api
alembic revision --autogenerate -m "describe change"   # review the generated file!
alembic upgrade head                                    # apply locally
```

Apply on the box (staging/prod):
```bash
docker exec wardrobe-api alembic upgrade head
```

First-time adoption on a DB that was bootstrapped with `create_all` (no
`alembic_version` table yet): stamp the baseline, then upgrade:
```bash
docker exec wardrobe-api alembic stamp c3027e371521   # the initial revision
docker exec wardrobe-api alembic upgrade head
```

CI runs the test suite against the models on every push (`.github/workflows/ci.yml`).

## Backup

```bash
infrastructure/backup.sh            # → infrastructure/backups/wardrobe-<ts>.sql.gz
```
Schedule nightly via cron (see the header of `backup.sh`). Keeps the last 14 dumps.

## Restore

```bash
gunzip -c infrastructure/backups/wardrobe-<ts>.sql.gz \
  | docker exec -i wardrobe-postgres psql -U wardrobe -d wardrobe
```

## Notes
- The MinIO object data lives under `infrastructure/data/minio` — back that up
  separately (rsync/snapshot) if you need to preserve avatars/scans.
- `RUN_JOBS_INLINE=false` moves avatar generation to the `wardrobe-worker`
  container; job status/progress is polled via `GET /jobs/{id}`.
