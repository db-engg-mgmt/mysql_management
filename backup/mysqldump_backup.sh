#!/usr/bin/env bash
# mysqldump_backup.sh - per-schema logical backup, consistent for InnoDB,
# compressed, with retention. Good enough up to tens of GB; past that use
# xtrabackup (backup/xtrabackup_backup.sh) or MySQL Shell dump utilities.
#
#   ./backup/mysqldump_backup.sh -o /backup/mysql -k 7 [-- mysql client args]
#
# Credentials: use a login path or ~/.my.cnf, never -p on the command line in cron.
#   mysql_config_editor set --login-path=backup --user=backup --password

set -uo pipefail

OUT=/backup/mysql; KEEP=7
while getopts "o:k:h" opt; do
  case $opt in
    o) OUT=$OPTARG ;; k) KEEP=$OPTARG ;;
    *) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

DEST="$OUT/$(date +%Y%m%d_%H%M)"
mkdir -p "$DEST"
LOG="$DEST/backup.log"
rc=0
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

COMMON=(--single-transaction --quick --routines --triggers --events
        --hex-blob --set-gtid-purged=OFF --source-data=2 --no-tablespaces)
# --source-data needs 8.0.26+, use --master-data=2 on older versions.
# --set-gtid-purged=OFF so the dump can be loaded into a server with its own GTIDs;
# set it to ON if you're seeding a replica.

schemas=$(mysql "$@" -N -B -e "SELECT schema_name FROM information_schema.schemata
  WHERE schema_name NOT IN ('mysql','information_schema','performance_schema','sys')")

# users and grants separately (mysql schema dumps don't restore cleanly across versions)
mysql "$@" -N -B -e "SELECT CONCAT('SHOW CREATE USER ''', user, '''@''', host, '''; SHOW GRANTS FOR ''', user, '''@''', host, ''';')
  FROM mysql.user WHERE user NOT LIKE 'mysql.%' AND user <> ''" \
  | mysql "$@" -N -B 2>>"$LOG" | sed 's/$/;/' > "$DEST/users_grants.sql" || { log "FAILED users"; rc=1; }

for s in $schemas; do
  log "dumping $s"
  if mysqldump "$@" "${COMMON[@]}" --databases "$s" 2>>"$LOG" | gzip -6 > "$DEST/$s.sql.gz"; then
    # a complete dump ends with this line
    if zcat "$DEST/$s.sql.gz" | tail -1 | grep -q "Dump completed"; then
      log "ok $s $(du -h "$DEST/$s.sql.gz" | cut -f1)"
    else
      log "FAILED $s (dump truncated)"; rc=1
    fi
  else
    log "FAILED $s"; rc=1
  fi
done

find "$OUT" -mindepth 1 -maxdepth 1 -type d -mtime +"$KEEP" -exec rm -rf {} +
[[ $rc -ne 0 ]] && log "finished WITH ERRORS" || log "finished"
exit $rc

# restore:  zcat appdb.sql.gz | mysql
# one table out of a full dump:
#   zcat appdb.sql.gz | sed -n '/^-- Table structure for table `orders`/,/^-- Table structure for table/p' > orders.sql
