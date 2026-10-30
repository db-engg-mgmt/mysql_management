-- source_binlogs.sql
-- Run on the SOURCE (primary): binlog config, size on disk, connected replicas.

SELECT @@log_bin, @@binlog_format, @@binlog_row_image, @@sync_binlog,
       @@gtid_mode, @@enforce_gtid_consistency,
       @@binlog_expire_logs_seconds / 86400 AS expire_days,
       @@max_binlog_size / 1024 / 1024      AS max_binlog_mb,
       @@server_id, @@server_uuid;

SHOW BINARY LOGS;
-- 8.4 also accepts SHOW BINARY LOG STATUS (SHOW MASTER STATUS is gone in 8.4)

-- replicas connected right now
SHOW REPLICAS;      -- 8.0.22+, SHOW SLAVE HOSTS before that

SELECT id, user, host, command, time, state
FROM performance_schema.processlist
WHERE command IN ('Binlog Dump', 'Binlog Dump GTID');

SELECT @@global.gtid_executed, @@global.gtid_purged;

-- Purge manually only after checking every replica has read past the file
-- (Relay_Source_Log_File / Source_Log_File in SHOW REPLICA STATUS on each):
--   PURGE BINARY LOGS TO 'binlog.000123';
--   PURGE BINARY LOGS BEFORE NOW() - INTERVAL 3 DAY;
