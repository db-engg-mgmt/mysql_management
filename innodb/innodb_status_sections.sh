#!/usr/bin/env bash
# innodb_status_sections.sh - dumps SHOW ENGINE INNODB STATUS to a timestamped
# file and prints the sections I usually care about.
#
#   ./innodb/innodb_status_sections.sh [mysql client args]
#   ./innodb/innodb_status_sections.sh -h db01 -u dba -p SEMAPHORES TRANSACTIONS
#
# Sections: BACKGROUND THREAD, SEMAPHORES, LATEST FOREIGN KEY ERROR,
# LATEST DETECTED DEADLOCK, TRANSACTIONS, FILE I/O, INSERT BUFFER AND ADAPTIVE HASH INDEX,
# LOG, BUFFER POOL AND MEMORY, ROW OPERATIONS

set -euo pipefail

args=()
sections=()
for a in "$@"; do
  if [[ $a =~ ^[A-Z][A-Z\ /]+$ ]]; then sections+=("$a"); else args+=("$a"); fi
done
[[ ${#sections[@]} -eq 0 ]] && sections=("SEMAPHORES" "TRANSACTIONS" "LOG" "BUFFER POOL AND MEMORY" "ROW OPERATIONS")

out="innodb_status_$(date +%Y%m%d_%H%M%S).txt"
mysql "${args[@]}" -r -B -N -e "SHOW ENGINE INNODB STATUS" | cut -f3- > "$out"
echo "full output saved to $out"

for s in "${sections[@]}"; do
  echo
  # a section header is an ALL CAPS line between two lines of dashes
  awk -v sec="$s" '
    { l[NR] = $0 }
    END {
      for (i = 2; i <= NR; i++) {
        hdr = (l[i-1] ~ /^-+$/ && l[i+1] ~ /^-+$/ && l[i] ~ /^[A-Z]/)
        if (hdr && l[i] == sec) { p = 1; print "== " sec; i++; continue }
        if (p && hdr) exit
        if (p && !(l[i] ~ /^-+$/ && l[i+1] ~ /^[A-Z]/ && l[i+2] ~ /^-+$/)) print l[i]
      }
    }' "$out" | head -80
done

# what to look for:
#   SEMAPHORES: long "has waited at ... for N seconds" lines = internal latch contention
#   TRANSACTIONS: "History list length", and transactions ACTIVE for a long time
#   LOG: Log sequence number vs Last checkpoint at = checkpoint age
#   ROW OPERATIONS: queries inside InnoDB / in queue (innodb_thread_concurrency)
