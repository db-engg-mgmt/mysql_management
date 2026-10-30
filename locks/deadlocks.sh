#!/usr/bin/env bash
# deadlocks.sh - pull the LATEST DETECTED DEADLOCK section out of
# SHOW ENGINE INNODB STATUS, plus the deadlock counter.
#
# InnoDB only keeps the most recent one. To keep all of them in the error log:
#   SET GLOBAL innodb_print_all_deadlocks = ON;
#
#   ./locks/deadlocks.sh                 # uses ~/.my.cnf
#   ./locks/deadlocks.sh -h db01 -u dba -p

set -euo pipefail

MYSQL=(mysql "$@" -N -B)

echo "Innodb_deadlocks since startup: $("${MYSQL[@]}" -e "SELECT variable_value FROM performance_schema.global_status WHERE variable_name='Innodb_deadlocks'")"
echo "innodb_print_all_deadlocks:     $("${MYSQL[@]}" -e "SELECT @@innodb_print_all_deadlocks")"
echo

# -B escapes newlines as \n in the Status column, -r turns that off
mysql "$@" -r -B -N -e "SHOW ENGINE INNODB STATUS" \
  | awk '/LATEST DETECTED DEADLOCK/{p=1} /^TRANSACTIONS$/{p=0} p' \
  | sed '/^-*$/d'

# grep the error log for older ones when print_all_deadlocks is on:
#   grep -n -A60 "Transactions deadlock detected" /var/log/mysql/error.log
# or summarize with pt-deadlock-logger.
