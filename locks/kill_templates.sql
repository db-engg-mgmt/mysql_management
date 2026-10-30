-- kill_templates.sql
-- Generates KILL statements instead of running them. Review the output, then
-- copy/paste what you actually want to kill. Nothing here kills by itself.
--
-- RDS/Aurora: use CALL mysql.rds_kill(<id>) / mysql.rds_kill_query(<id>) instead.

-- 1. queries running longer than 10 minutes (skip replication threads and system users)
SELECT CONCAT('KILL QUERY ', id, ';') AS cmd, user, host, time, LEFT(info, 80) AS query
FROM performance_schema.processlist
WHERE command = 'Query'
  AND time > 600
  AND user NOT IN ('system user', 'event_scheduler', 'rdsadmin')
  AND id <> CONNECTION_ID();

-- 2. sleeping connections holding a transaction open > 5 min
SELECT CONCAT('KILL ', p.id, ';') AS cmd, p.user, p.host,
       TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) AS trx_secs, t.trx_rows_locked
FROM performance_schema.processlist p
JOIN information_schema.innodb_trx t ON t.trx_mysql_thread_id = p.id
WHERE p.command = 'Sleep'
  AND t.trx_started < NOW() - INTERVAL 5 MINUTE;

-- 3. everything from one user (e.g. a runaway batch)
-- SELECT CONCAT('KILL ', id, ';') FROM performance_schema.processlist WHERE user = 'batch_user';

-- Remember a killed big UPDATE/DELETE has to roll back, which can take as long as
-- it ran. Watch it with:
--   SELECT trx_mysql_thread_id, trx_state, trx_rows_modified FROM information_schema.innodb_trx;
-- trx_rows_modified counts down while rolling back.

-- Prevention:
--   SET GLOBAL max_execution_time = 60000;   -- ms, SELECT only
--   wait_timeout / interactive_timeout for idle conns
