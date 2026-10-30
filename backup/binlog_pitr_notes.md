# Point in time recovery with binlogs

Restore the latest full backup, then replay binlogs up to just before the bad statement.

## 1. Find the bad event

```bash
# position of the backup (from xtrabackup_binlog_info, or the CHANGE ... SOURCE line in a dump)
cat /backup/xtra/20261025_0100_full/xtrabackup_binlog_info
#   binlog.000412   1585   <gtid set>

# search binlogs for the DROP / bad DELETE
mysqlbinlog --base64-output=DECODE-ROWS -vv /var/lib/mysql/binlog.000418 | grep -n -i -B5 "drop table orders"
```

Note the position (`# at 88231`) or the GTID (`SET @@SESSION.GTID_NEXT= 'uuid:123456'`).

## 2. Restore the backup to a *separate* instance

Never to prod directly. Restore to a scratch host, then copy the affected data back.

## 3. Replay binlogs up to the bad event

Position based:

```bash
mysqlbinlog --start-position=1585 /binlogs/binlog.000412 > replay.sql
mysqlbinlog /binlogs/binlog.000413 ... /binlogs/binlog.000417 >> replay.sql
mysqlbinlog --stop-position=88231 /binlogs/binlog.000418 >> replay.sql
mysql < replay.sql
```

GTID based (easier with multiple files), skip only the bad transaction:

```bash
mysqlbinlog --skip-gtids=false --exclude-gtids='uuid:123456' \
    /binlogs/binlog.000412 ... binlog.000420 | mysql
```

Pass all files to a single mysqlbinlog call when temp tables are involved; separate
invocations lose session state between files.

## 4. Copy the data back

```bash
mysqldump --single-transaction appdb orders > orders_recovered.sql
# load into prod under a different name, compare, then swap/merge
```

## Gotchas

- `binlog_expire_logs_seconds` decides how far back you can go. Copy binlogs off the
  box (`mysqlbinlog --read-from-remote-server --raw --stop-never`) if you need longer.
- `binlog_format=ROW` is required for reliable replay; with `binlog_row_image=FULL`
  you can also reverse individual DML with tools like binlog2sql / MyFlash.
