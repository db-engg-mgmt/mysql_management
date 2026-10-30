#!/usr/bin/env bash
# replica_status.sh - compact view of SHOW REPLICA STATUS (8.0.22+ naming;
# falls back to SHOW SLAVE STATUS on older servers).
#
#   ./replication/replica_status.sh                 # ~/.my.cnf
#   ./replication/replica_status.sh -h replica02 -u dba -p
#
# Exit code 0 = both threads running and lag under LAG_WARN seconds (default 300),
# 1 = lag over threshold, 2 = a thread is stopped / error. Usable from cron/nagios.

LAG_WARN=${LAG_WARN:-300}

ver=$(mysql "$@" -N -B -e "SELECT @@version") || exit 2
if printf '%s\n8.0.22\n' "${ver%%-*}" | sort -V -C; then
  stmt="SHOW SLAVE STATUS"; io=Slave_IO_Running; sql=Slave_SQL_Running; lag=Seconds_Behind_Master; src=Master_Host
else
  stmt="SHOW REPLICA STATUS"; io=Replica_IO_Running; sql=Replica_SQL_Running; lag=Seconds_Behind_Source; src=Source_Host
fi

out=$(mysql "$@" -e "$stmt\G")
[[ -z $out ]] && { echo "not a replica (no replication configured)"; exit 0; }

get() { awk -F': ' -v k="$1" '$1 ~ "^ *"k"$" {sub(/^[^:]*: /, ""); print; exit}' <<< "$out"; }

printf "%-28s %s\n" "source"            "$(get $src):$(get Source_Port)$(get Master_Port)"
printf "%-28s %s\n" "channel"           "$(get Channel_Name)"
printf "%-28s %s\n" "io thread"         "$(get $io)"
printf "%-28s %s\n" "sql thread"        "$(get $sql)"
printf "%-28s %s\n" "seconds behind"    "$(get $lag)"
printf "%-28s %s\n" "sql delay"         "$(get SQL_Delay)"
printf "%-28s %s\n" "last io error"     "$(get Last_IO_Error)"
printf "%-28s %s\n" "last sql error"    "$(get Last_SQL_Error)"
printf "%-28s %s\n" "auto position"     "$(get Auto_Position)"
printf "%-28s %s\n" "retrieved gtid"    "$(get Retrieved_Gtid_Set | cut -c1-120)"
printf "%-28s %s\n" "executed gtid"     "$(get Executed_Gtid_Set | cut -c1-120)"
printf "%-28s %s\n" "sql state"         "$(get Replica_SQL_Running_State)$(get Slave_SQL_Running_State)"

[[ $(get $io) != "Yes" || $(get $sql) != "Yes" ]] && exit 2
l=$(get $lag); [[ $l == "NULL" || -z $l ]] && exit 2
(( l > LAG_WARN )) && exit 1
exit 0

# Seconds_Behind_Source only measures the SQL thread vs the relay log. If the IO
# thread is behind too (network), it lies. pt-heartbeat or the 8.0
# replication_applier_status_by_worker timestamps (replication/applier_lag.sql)
# give a truer number.
