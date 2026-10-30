#!/usr/bin/env bash
# purge_old_rows.sh - delete old rows in small batches so you don't create one
# giant transaction (huge undo, replica lag, long row locks).
#
#   ./maintenance/purge_old_rows.sh -t appdb.audit_log -c created_at -k 90 [-b 5000] [-s 0.5] [-x]
#
#   -t  schema.table
#   -c  datetime column to filter on (should be indexed!)
#   -k  keep this many days
#   -b  rows per batch (default 5000)
#   -s  sleep seconds between batches (default 0.5) - raise it if replicas lag
#   -x  execute (default: just count what would be deleted)
#
# pt-archiver does this too, with more options (archiving to another table/file).
# For time-series tables, partition by date and DROP PARTITION instead.

set -euo pipefail

TBL=""; COL=""; KEEP=""; BATCH=5000; SLEEP=0.5; EXEC=0
while getopts "t:c:k:b:s:xh" opt; do
  case $opt in
    t) TBL=$OPTARG ;; c) COL=$OPTARG ;; k) KEEP=$OPTARG ;;
    b) BATCH=$OPTARG ;; s) SLEEP=$OPTARG ;; x) EXEC=1 ;;
    *) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
[[ -z $TBL || -z $COL || -z $KEEP ]] && { echo "need -t -c -k"; exit 1; }

MYSQL=(mysql "$@" -N -B)
WHERE="\`$COL\` < NOW() - INTERVAL $KEEP DAY"

todo=$("${MYSQL[@]}" -e "SELECT COUNT(*) FROM $TBL WHERE $WHERE")
echo "$(date '+%F %T') $TBL: $todo rows older than $KEEP days"
[[ $EXEC -eq 0 ]] && { echo "dry run, add -x"; exit 0; }

total=0
while :; do
  n=$("${MYSQL[@]}" -e "DELETE FROM $TBL WHERE $WHERE ORDER BY \`$COL\` LIMIT $BATCH; SELECT ROW_COUNT();")
  total=$((total + n))
  (( n == 0 )) && break
  (( total % (BATCH * 20) == 0 )) && echo "$(date '+%F %T') deleted $total"
  sleep "$SLEEP"
done
echo "$(date '+%F %T') done, deleted $total from $TBL"
