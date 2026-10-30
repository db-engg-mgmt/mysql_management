#!/usr/bin/env bash
# xtrabackup_backup.sh - physical hot backup with Percona XtraBackup 8.0/8.4.
# Full backup on Sunday, incrementals the rest of the week based on the last one.
#
#   ./backup/xtrabackup_backup.sh -o /backup/xtra [-f]   (-f forces a full)
#
# XtraBackup major version must match the server (8.0.x for 8.0, 8.4.x for 8.4).
# The backup user needs: BACKUP_ADMIN, PROCESS, RELOAD, LOCK TABLES, REPLICATION CLIENT,
# SELECT on performance_schema.log_status, SELECT on performance_schema.keyring_component_status.

set -euo pipefail

OUT=/backup/xtra; FULL=0
while getopts "o:fh" opt; do
  case $opt in
    o) OUT=$OPTARG ;; f) FULL=1 ;;
    *) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done

mkdir -p "$OUT"
STAMP=$(date +%Y%m%d_%H%M)
last=$(ls -1d "$OUT"/*_full "$OUT"/*_inc 2>/dev/null | sort | tail -1 || true)

if [[ $FULL -eq 1 || $(date +%u) -eq 7 || -z $last ]]; then
  target="$OUT/${STAMP}_full"
  echo "$(date '+%F %T') full backup -> $target"
  xtrabackup --backup --target-dir="$target" --parallel=4 --compress=zstd --compress-threads=4 \
    2> "$target.log"
else
  target="$OUT/${STAMP}_inc"
  echo "$(date '+%F %T') incremental on top of $last -> $target"
  xtrabackup --backup --target-dir="$target" --incremental-basedir="$last" \
    --parallel=4 --compress=zstd --compress-threads=4 2> "$target.log"
fi

tail -1 "$target.log" | grep -q "completed OK" || { echo "BACKUP FAILED, see $target.log"; exit 1; }
echo "$(date '+%F %T') ok $(du -sh "$target" | cut -f1)"
grep -h "binlog_pos\|GTID" "$target/xtrabackup_binlog_info" 2>/dev/null || true

# Restore outline (full + incrementals):
#   xtrabackup --decompress --target-dir=FULL     (and each INC)
#   xtrabackup --prepare --apply-log-only --target-dir=FULL
#   xtrabackup --prepare --apply-log-only --target-dir=FULL --incremental-dir=INC1
#   xtrabackup --prepare                  --target-dir=FULL --incremental-dir=LAST_INC
#   systemctl stop mysqld; mv /var/lib/mysql /var/lib/mysql.old
#   xtrabackup --copy-back --target-dir=FULL; chown -R mysql: /var/lib/mysql; systemctl start mysqld
# Test restores regularly. A backup nobody has restored is a guess.
