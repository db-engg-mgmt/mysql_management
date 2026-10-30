-- processlist.sql
-- Better SHOW FULL PROCESSLIST. Uses performance_schema.processlist (8.0.22+),
-- which doesn't take the global mutex the old information_schema version did.
-- Falls back fine on older 8.0 if you swap the FROM to information_schema.processlist.
--
--   mysql -t < monitoring/processlist.sql

SELECT
    p.id,
    p.user,
    SUBSTRING_INDEX(p.host, ':', 1)          AS client,
    p.db,
    p.command,
    p.time                                   AS secs,
    p.state,
    t.trx_state,
    TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) AS trx_secs,
    t.trx_rows_locked,
    t.trx_rows_modified,
    LEFT(REGEXP_REPLACE(COALESCE(p.info, ''), '[[:space:]]+', ' '), 120) AS query
FROM performance_schema.processlist p
LEFT JOIN information_schema.innodb_trx t ON t.trx_mysql_thread_id = p.id
WHERE p.command NOT IN ('Daemon', 'Binlog Dump', 'Binlog Dump GTID')
  AND p.id <> CONNECTION_ID()
  AND (p.command <> 'Sleep' OR t.trx_id IS NOT NULL)   -- hide idle conns unless they hold a trx
ORDER BY p.time DESC;

-- connection count by state
SELECT command, state, COUNT(*) AS n
FROM performance_schema.processlist
GROUP BY command, state
ORDER BY n DESC;
