-- history_list.sql
-- Purge lag. History list length (HLL) = undo records not yet purged.
-- It climbs when a long transaction (or a long-running consistent read on a
-- REPEATABLE READ snapshot) keeps old row versions alive. High HLL makes every
-- read slower because InnoDB walks longer version chains.
--
-- A few thousand is normal. Hundreds of thousands to millions = find the old trx.

SELECT name, count AS value
FROM information_schema.innodb_metrics
WHERE name IN ('trx_rseg_history_len', 'purge_del_mark_records', 'purge_upd_exist_or_extern_records',
               'purge_invoked', 'purge_undo_log_pages');
-- trx_rseg_history_len is enabled by default; if 0 and you expect otherwise:
--   SET GLOBAL innodb_monitor_enable = 'trx_rseg_history_len';

-- oldest transactions, these are the usual cause
SELECT trx_mysql_thread_id AS id, trx_state, trx_started,
       TIMESTAMPDIFF(SECOND, trx_started, NOW()) AS secs,
       trx_isolation_level, trx_is_read_only, LEFT(trx_query, 100) AS query
FROM information_schema.innodb_trx
ORDER BY trx_started
LIMIT 10;

-- undo tablespace sizes (8.0 truncates automatically when innodb_undo_log_truncate=ON)
SELECT tablespace_name, file_name,
       ROUND(total_extents * extent_size / 1024 / 1024) AS size_mb
FROM information_schema.files
WHERE file_type = 'UNDO LOG';

SELECT @@innodb_purge_threads, @@innodb_max_purge_lag, @@innodb_undo_log_truncate, @@innodb_max_undo_log_size;
