#!/usr/bin/env bash
# COIL Project A nightly backup: DB dump + restic to Amazon S3 (instance role, no keys).
# Run as root (cron does this). Manual run: sudo /opt/coil/scripts/backup.sh
set -euo pipefail
source /root/.restic.env
COMPOSE_DIR=/opt/coil/compose
DATA_DIR=/srv/nextcloud
LOG=/var/log/coil-backup.log
STATUS=/var/lib/coil/backup-status.json
mkdir -p /var/lib/coil
START=$(date +%s)

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }
write_status() {
  printf '{"time":"%s","result":"%s","duration_s":%s,"snapshot":"%s"}\n' \
    "$(date '+%F %H:%M')" "$1" "$(( $(date +%s) - START ))" "${2:-}" > "$STATUS"
}
maintenance_off() {
  (cd "$COMPOSE_DIR" && docker compose exec -T -u www-data app php occ maintenance:mode --off) >/dev/null 2>&1 || true
}
on_error() { maintenance_off; log "Backup FAILED near line $1"; write_status FAILED; }
trap 'on_error $LINENO' ERR


log "Backup started"
cd "$COMPOSE_DIR"
docker compose exec -T -u www-data app php occ maintenance:mode --on
docker compose exec -T db sh -c 'exec mariadb-dump --single-transaction --default-character-set=utf8mb4 -u root -p"$MARIADB_ROOT_PASSWORD" nextcloud' > "$DATA_DIR/dbdump/nextcloud.sql"
log "Database dumped: $(du -h "$DATA_DIR/dbdump/nextcloud.sql" | cut -f1)"

restic backup --tag nightly --exclude "$DATA_DIR/db" "$DATA_DIR" /opt/coil /etc/wireguard >> "$LOG" 2>&1
maintenance_off
log "Upload finished, maintenance mode off"

restic forget --tag nightly --keep-daily 7 --keep-weekly 4 --prune >> "$LOG" 2>&1
restic check >> "$LOG" 2>&1

SNAP=$(restic snapshots --latest 1 --tag nightly --json | python3 -c 'import json,sys; s=json.load(sys.stdin); print(s[-1]["short_id"] if s else "")')
write_status OK "$SNAP"
cp "$STATUS" /var/lib/coil/backup-last-ok.json
log "Backup OK: snapshot $SNAP in $(( $(date +%s) - START )) s"
