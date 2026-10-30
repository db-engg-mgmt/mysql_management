-- innodb_lock_waits.sql
-- Row lock waits: who is waiting, who is blocking, and on which index/rows.
-- MySQL 8.0+ (performance_schema.data_lock_waits replaced information_schema.innodb_lock_waits).
--
-- Note: before 8.0.21-ish, querying sys.innodb_lock_waits on a box with
-- thousands of waits was itself expensive (bug #100537). The direct query below is lighter.

SELECT
    r.trx_mysql_thread_id                        AS waiting_id,
    TIMESTAMPDIFF(SECOND, r.trx_wait_started, NOW()) AS wait_secs,
    LEFT(r.trx_query, 80)                        AS waiting_query,
    b.trx_mysql_thread_id                        AS blocking_id,
    TIMESTAMPDIFF(SECOND, b.trx_started, NOW())  AS blocking_trx_secs,
    bp.command                                   AS blocking_cmd,     -- 'Sleep' = app left a trx open
    LEFT(b.trx_query, 80)                        AS blocking_query,
    CONCAT(bl.object_schema, '.', bl.object_name) AS locked_table,
    bl.index_name,
    bl.lock_type,
    bl.lock_mode                                 AS blocking_mode,
    rl.lock_mode                                 AS requested_mode,
    bl.lock_data
FROM performance_schema.data_lock_waits w
JOIN information_schema.innodb_trx b  ON b.trx_id = w.blocking_engine_transaction_id
JOIN information_schema.innodb_trx r  ON r.trx_id = w.requesting_engine_transaction_id
JOIN performance_schema.data_locks bl ON bl.engine_lock_id = w.blocking_engine_lock_id
JOIN performance_schema.data_locks rl ON rl.engine_lock_id = w.requesting_engine_lock_id
LEFT JOIN performance_schema.processlist bp ON bp.id = b.trx_mysql_thread_id
ORDER BY wait_secs DESC;

-- root blockers: blocking others but not waiting on anyone
SELECT
    b.trx_mysql_thread_id AS root_blocker_id,
    COUNT(DISTINCT w.requesting_engine_transaction_id) AS blocking_n,
    TIMESTAMPDIFF(SECOND, b.trx_started, NOW()) AS trx_secs,
    LEFT(b.trx_query, 100) AS query,
    CONCAT('KILL ', b.trx_mysql_thread_id, ';') AS kill_cmd
FROM performance_schema.data_lock_waits w
JOIN information_schema.innodb_trx b ON b.trx_id = w.blocking_engine_transaction_id
WHERE b.trx_id NOT IN (SELECT requesting_engine_transaction_id FROM performance_schema.data_lock_waits)
GROUP BY b.trx_mysql_thread_id, b.trx_started, b.trx_query
ORDER BY blocking_n DESC;

-- blocking_query NULL = the blocker is idle. Find what it ran last:
--   SELECT * FROM performance_schema.events_statements_history
--   WHERE thread_id = PS_THREAD_ID(<blocking_id>) ORDER BY event_id;
