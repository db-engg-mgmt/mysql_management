-- redo_log.sql
-- Redo log sizing and checkpoint age.
-- 8.0.30+ uses innodb_redo_log_capacity (resizable online) instead of
-- innodb_log_file_size * innodb_log_files_in_group.
--
-- Rule of thumb: redo capacity should hold roughly an hour of writes at peak.
-- Too small -> furious flushing ("sync flush") when checkpoint age hits the limit.

SELECT @@version,
       @@innodb_redo_log_capacity / 1024 / 1024 AS redo_capacity_mb,   -- 8.0.30+
       @@innodb_flush_log_at_trx_commit,
       @@sync_binlog,
       @@innodb_log_buffer_size / 1024 / 1024 AS log_buffer_mb;

-- current LSN vs checkpoint (metrics enabled by default in 8.0)
SELECT name, count
FROM information_schema.innodb_metrics
WHERE name IN ('log_lsn_current', 'log_lsn_last_checkpoint', 'log_lsn_checkpoint_age',
               'log_max_modified_age_async', 'log_max_modified_age_sync', 'log_waits');

-- 8.0.30+ redo consumption
SELECT variable_name, variable_value
FROM performance_schema.global_status
WHERE variable_name IN ('Innodb_redo_log_capacity_resized', 'Innodb_redo_log_logical_size',
                        'Innodb_redo_log_physical_size', 'Innodb_redo_log_checkpoint_lsn',
                        'Innodb_redo_log_current_lsn', 'Innodb_os_log_written', 'Innodb_log_waits');

-- Measure write rate: note Innodb_os_log_written, wait 60s, subtract, multiply by 60 for MB/hour.
-- Innodb_log_waits > 0 -> innodb_log_buffer_size too small.
-- Resize online (8.0.30+):  SET GLOBAL innodb_redo_log_capacity = 8 * 1024 * 1024 * 1024;
