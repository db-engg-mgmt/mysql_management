#!/usr/bin/env bash
# analyze_tables.sh - ANALYZE TABLE for every InnoDB table in a schema whose
# persistent stats are older than N days. ANALYZE is cheap on InnoDB (samples
# innodb_stats_persistent_sample_pages pages) but still takes a brief lock and
# flushes the table from the table cache, so don't loop it at peak.
#
#   ./maintenance/analyze_tables.sh -d appdb [-a 7] [-x] [-- mysql client args]
#   -x  actually run (default is to print what would run)

set -euo pipefail

DB=""; AGE=7; EXEC=0
while getopts "d:a:xh" opt; do
  case $opt in
    d) DB=$OPTARG ;; a) AGE=$OPTARG ;; x) EXEC=1 ;;
    *) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
[[ -z $DB ]] && { echo "need -d schema"; exit 1; }

MYSQL=(mysql "$@" -N -B)

tables=$("${MYSQL[@]}" -e "
  SELECT CONCAT('\`', s.table_name, '\`')
  FROM mysql.innodb_table_stats s
  JOIN information_schema.tables t ON t.table_schema = s.database_name AND t.table_name = s.table_name
  WHERE s.database_name = '$DB'
    AND s.last_update < NOW() - INTERVAL $AGE DAY
    AND t.table_type = 'BASE TABLE'
  ORDER BY s.last_update")

[[ -z $tables ]] && { echo "all stats in $DB newer than $AGE days"; exit 0; }

for t in $tables; do
  if [[ $EXEC -eq 1 ]]; then
    echo "$(date '+%F %T') ANALYZE TABLE $DB.$t"
    "${MYSQL[@]}" -e "ANALYZE TABLE \`$DB\`.$t" | awk '{print "   ", $3, $4}'
  else
    echo "would run: ANALYZE TABLE \`$DB\`.$t"
  fi
done
