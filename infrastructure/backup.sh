#!/usr/bin/env bash
# Backup the Virtual Wardrobe Postgres DB (and optionally MinIO data).
# Usage:  ./backup.sh            # writes ./backups/wardrobe-<ts>.sql.gz
# Cron:   0 3 * * *  /home/appbox/virtual-wardrobe/infrastructure/backup.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/backups"
mkdir -p "$OUT"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
DB_USER="${POSTGRES_USER:-wardrobe}"
DB_NAME="${POSTGRES_DB:-wardrobe}"

echo "Dumping database $DB_NAME…"
docker exec wardrobe-postgres pg_dump -U "$DB_USER" -d "$DB_NAME" \
  | gzip > "$OUT/wardrobe-$TS.sql.gz"
echo "Wrote $OUT/wardrobe-$TS.sql.gz"

# Retain the 14 most recent dumps.
ls -1t "$OUT"/wardrobe-*.sql.gz 2>/dev/null | tail -n +15 | xargs -r rm -f
echo "Backup complete."
