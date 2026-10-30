-- long_running.sql
-- Statements running longer than 60s and transactions open longer than 60s.
-- Change the 60 to taste.
--
-- A "Sleep" connection holding an open transaction is the MySQL equivalent of
-- postgres "idle in transaction": it holds locks and stops purge, so the
-- history list length grows (see innodb/history_list.sql).

SELECT id, user, host, db, command, time AS secs, state,
       LEFT(info, 200) AS query
FROM performance_schema.processlist
WHERE command NOT IN ('Sleep', 'Daemon', 'Binlog Dump', 'Binlog Dump GTID')
  AND time > 60
  AND id <> CONNECTION_ID()
ORDER BY time DESC;

SELECT
    t.trx_mysql_thread_id                         AS id,
    p.user,
    p.host,
    p.command,
    t.trx_state,
    t.trx_started,
    TIMESTAMPDIFF(SECOND, t.trx_started, NOW())   AS trx_secs,
    t.trx_isolation_level,
    t.trx_rows_locked,
    t.trx_rows_modified,
    t.trx_tables_locked,
    LEFT(t.trx_query, 120)                        AS current_query
FROM information_schema.innodb_trx t
LEFT JOIN performance_schema.processlist p ON p.id = t.trx_mysql_thread_id
WHERE t.trx_started < NOW() - INTERVAL 60 SECOND
ORDER BY t.trx_started;

-- the last statement an idle trx ran (sys schema):
--   SELECT * FROM sys.session WHERE conn_id = <id>\G   -- look at last_statement

-- kill just the statement:  KILL QUERY <id>;
-- kill the connection:      KILL <id>;
