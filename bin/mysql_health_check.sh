#!/usr/bin/env bash
# mysql_health_check.sh - runs the main read-only diagnostic scripts and writes
# one report file. Extra arguments go straight to the mysql client.
#
#   ./bin/mysql_health_check.sh                         # ~/.my.cnf
#   ./bin/mysql_health_check.sh --login-path=dba -h db01
#   OUTDIR=/tmp ./bin/mysql_health_check.sh
#
# Needs: PROCESS, REPLICATION CLIENT, SELECT on performance_schema/sys/mysql.

set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR=${OUTDIR:-.}

host=$(mysql "$@" -N -B -e "SELECT @@hostname") || exit 1
report="$OUTDIR/mysql_health_${host}_$(date +%Y%m%d_%H%M).txt"

scripts=(
  monitoring/status_overview.sql
  monitoring/connections.sql
  monitoring/processlist.sql
  monitoring/long_running.sql
  locks/innodb_lock_waits.sql
  locks/metadata_locks.sql
  innodb/buffer_pool.sql
  innodb/history_list.sql
  innodb/redo_log.sql
  performance/top_statements.sql
  performance/memory_usage.sql
  indexes/unused_indexes.sql
  indexes/redundant_indexes.sql
  indexes/tables_without_pk.sql
  schema/sizes.sql
  schema/auto_increment_capacity.sql
  replication/applier_lag.sql
  config/key_variables.sql
  security/users_audit.sql
)

{
  echo "mysql health check: host=$host run=$(date '+%F %T %Z') by=$(whoami)"
  for s in "${scripts[@]}"; do
    echo
    echo "################ $s"
    mysql "$@" -t --force < "$HERE/$s" 2>&1
  done
  echo
  echo "################ replication/replica_status.sh"
  "$HERE/replication/replica_status.sh" "$@" 2>&1
} > "$report"

echo "written: $report"
