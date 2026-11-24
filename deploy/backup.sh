#!/bin/sh
# daily pg_dump at BACKUP_HOUR, "now" = run once and exit
# needs the PG* env vars
set -u

BACKUP_DIR=/backups
HOUR="${BACKUP_HOUR:-3}"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') backup: $*"; }

case "$HOUR" in
  ''|*[!0-9]*) log "invalid BACKUP_HOUR: '$HOUR'"; exit 1 ;;
esac
case "$KEEP_DAYS" in
  ''|*[!0-9]*) log "invalid BACKUP_KEEP_DAYS: '$KEEP_DAYS'"; exit 1 ;;
esac
if [ "$HOUR" -gt 23 ]; then log "BACKUP_HOUR must be 0-23"; exit 1; fi

run_backup() {
  name="planner-$(date +%Y-%m-%d_%H%M).dump"
  tmp="$BACKUP_DIR/.$name.tmp"
  if pg_dump -Fc -f "$tmp" && [ -s "$tmp" ] && mv "$tmp" "$BACKUP_DIR/$name"; then
    size=$(wc -c < "$BACKUP_DIR/$name")
    find "$BACKUP_DIR" -maxdepth 1 -name 'planner-*.dump' -type f -mtime +"$KEEP_DAYS" -delete
    n=$(find "$BACKUP_DIR" -maxdepth 1 -name 'planner-*.dump' -type f | wc -l)
    log "ok $name ($size bytes), $n backups kept (retention $KEEP_DAYS days)"
    return 0
  fi
  rm -f "$tmp"
  log "FAILED $name"
  return 1
}

if [ "${1:-}" = "now" ]; then
  run_backup
  exit $?
fi

log "started, daily at $HOUR:00 ($(date +%Z))"
while true; do
  h=$(date +%H); m=$(date +%M); s=$(date +%S)
  h=${h#0}; m=${m#0}; s=${s#0}
  wait=$(( (HOUR * 3600 - (${h:-0} * 3600 + ${m:-0} * 60 + ${s:-0})) % 86400 ))
  [ "$wait" -le 0 ] && wait=$((wait + 86400))
  sleep "$wait"
  run_backup || true
done
