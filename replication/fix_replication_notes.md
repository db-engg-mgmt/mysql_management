# Fixing a broken replica

Notes for the common ones. Always find out *why* it broke before skipping anything -
a skipped transaction means the replica no longer matches the source.

## Check what's wrong

```sql
SHOW REPLICA STATUS\G
SELECT * FROM performance_schema.replication_applier_status_by_worker\G
```

`Last_SQL_Errno` is the thing to look up.

## 1062 duplicate key / 1032 row not found

The replica's data has drifted (someone wrote to it, or a skip happened earlier).

GTID setup - inject an empty transaction for the failing GTID:

```sql
STOP REPLICA;
SET GTID_NEXT = 'source-uuid:12345';    -- from Last_SQL_Error / applying_transaction
BEGIN; COMMIT;
SET GTID_NEXT = 'AUTOMATIC';
START REPLICA;
```

Non-GTID:

```sql
STOP REPLICA;
SET GLOBAL sql_replica_skip_counter = 1;   -- sql_slave_skip_counter before 8.0.26
START REPLICA;
```

Then run `pt-table-checksum` from the source and `pt-table-sync` to repair. If lots
of tables are off, rebuild the replica instead.

Make sure it doesn't happen again: `super_read_only = ON` on every replica.

## 1236 source purged binlogs the replica still needs

The replica was down longer than `binlog_expire_logs_seconds`. No way to recover from
binlogs - rebuild from a fresh backup (clone plugin is the quickest on 8.0.17+):

```sql
-- on the replica
SET GLOBAL clone_valid_donor_list = 'source01:3306';
CLONE INSTANCE FROM 'clone_user'@'source01':3306 IDENTIFIED BY '...';
-- restarts automatically, then:
CHANGE REPLICATION SOURCE TO SOURCE_HOST='source01', SOURCE_USER='repl',
  SOURCE_PASSWORD='...', SOURCE_AUTO_POSITION=1, GET_SOURCE_PUBLIC_KEY=1;
START REPLICA;
```

## Relay log corrupted (after a crash)

With GTID + auto position, just throw the relay logs away and re-fetch:

```sql
STOP REPLICA;
RESET REPLICA;          -- keeps connection settings, deletes relay logs
START REPLICA;
```

`relay_log_recovery = ON` in my.cnf does this automatically on startup. It should be on.

## Lag that won't go down

- `replication/applier_lag.sql` - is it one worker / one huge transaction?
- tables without PK under row based replication (`indexes/tables_without_pk.sql`)
- replica I/O capacity lower than source
- `replica_parallel_workers` = 0 or 1
- long running reports on the replica holding metadata locks
- as a stopgap on a replica you can rebuild: `innodb_flush_log_at_trx_commit = 2`, `sync_binlog = 0`
