# mysql_management

Scripts and notes for day to day MySQL administration and troubleshooting:
sessions, locks, InnoDB internals, slow statements, indexes, replication,
backups and upgrades.

Targets MySQL 8.0 and 8.4 LTS (InnoDB). Most scripts lean on `performance_schema`
and the `sys` schema, both on by default since 5.7. Where 8.0 renamed things
(`REPLICA`/`SOURCE` vs `SLAVE`/`MASTER`) the scripts use the new names; comments
mention the old ones. Percona Server works the same. MariaDB diverged enough
that some of the p_s / sys queries won't work there.

## Layout

| dir | what's in it |
|---|---|
| `monitoring/` | processlist with trx info, long queries / open transactions, status overview, connections |
| `locks/` | InnoDB row lock waits + root blocker, metadata locks, last deadlock, KILL generators |
| `innodb/` | buffer pool, history list length / purge lag, redo log, I/O, INNODB STATUS parser |
| `performance/` | top statement digests, sys schema quick checks, table I/O, memory, slow log, EXPLAIN |
| `indexes/` | unused, redundant, tables without PK, index stats |
| `schema/` | sizes, fragmentation, AUTO_INCREMENT headroom, engines / charsets, partitions |
| `replication/` | replica status (with exit codes for monitoring), applier lag, binlogs, group replication, fix notes |
| `security/` | account audit, security related settings |
| `config/` | key variables and where they were set, example my.cnf |
| `maintenance/` | stale stats ANALYZE, batched purge of old rows |
| `backup/` | mysqldump per schema, xtrabackup full/incremental, binlog PITR notes |
| `upgrade/` | pre-upgrade SQL checks, 8.0 -> 8.4 runbook |
| `bin/` | `mysql_health_check.sh` - runs everything read-only into one report |

## Usage

```bash
mysql -t < monitoring/processlist.sql
mysql -t appdb < indexes/index_stats.sql
mysql -t -e "SET @db='appdb'; SOURCE schema/partitions.sql"

./replication/replica_status.sh -h replica01
./bin/mysql_health_check.sh --login-path=dba
```

`-t` keeps the table borders when reading from a file. For wide rows, run
interactively and end the statement with `\G`.

Shell scripts pass any extra arguments to the `mysql` client, so `-h`, `-P`,
`--login-path` etc. all work. Keep passwords in `~/.my.cnf` or a login path
(`mysql_config_editor`), not on the command line.

What I run first when something is on fire:

1. `monitoring/processlist.sql`
2. `locks/innodb_lock_waits.sql` and `locks/metadata_locks.sql`
3. `monitoring/long_running.sql`
4. `innodb/history_list.sql` if things are slow in general and nothing is obviously blocked
5. `performance/top_statements.sql`

## Privileges

A monitoring account that can run everything except the backup/maintenance scripts:

```sql
CREATE USER 'dba_ro'@'10.%' IDENTIFIED BY '...';
GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'dba_ro'@'10.%';
GRANT SELECT ON performance_schema.* TO 'dba_ro'@'10.%';
GRANT SELECT ON sys.* TO 'dba_ro'@'10.%';
GRANT SELECT ON mysql.* TO 'dba_ro'@'10.%';
GRANT EXECUTE ON sys.* TO 'dba_ro'@'10.%';
```

## Useful tools alongside these

- Percona Toolkit: `pt-query-digest`, `pt-online-schema-change`, `pt-table-checksum`,
  `pt-duplicate-key-checker`, `pt-archiver`, `pt-stalk`
- `gh-ost` for online schema changes
- MySQL Shell: upgrade checker, dump/load utilities, InnoDB Cluster admin
- Percona XtraBackup

## References

Places I've picked up queries and ideas from:

- [MySQL Reference Manual - sys schema](https://dev.mysql.com/doc/refman/8.4/en/sys-schema.html)
- [MySQL Reference Manual - InnoDB transaction and locking information](https://dev.mysql.com/doc/refman/8.0/en/innodb-information-schema-transactions.html)
- [aadant/dbahelper](https://github.com/aadant/dbahelper)
- [HariSekhon/SQL-scripts](https://github.com/HariSekhon/SQL-scripts)
- Percona blog and Percona Toolkit docs

## Disclaimer

Test outside production first. Anything that kills, deletes or rebuilds is dry-run
by default or only prints the statements.

MIT licensed.
