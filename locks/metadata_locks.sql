-- metadata_locks.sql
-- "Waiting for table metadata lock". Usually an ALTER/DDL queued behind an open
-- transaction that touched the table, with every new query queued behind the ALTER.
--
-- The MDL instrument is on by default in 8.0. If metadata_locks is empty, check:
--   SELECT * FROM performance_schema.setup_instruments WHERE name = 'wait/lock/metadata/sql/mdl';

SELECT
    ml.object_type,
    ml.object_schema,
    ml.object_name,
    ml.lock_type,
    ml.lock_duration,
    ml.lock_status,                     -- GRANTED or PENDING
    t.processlist_id                    AS conn_id,
    t.processlist_user                  AS user,
    t.processlist_command               AS cmd,
    t.processlist_time                  AS secs,
    LEFT(t.processlist_info, 80)        AS query
FROM performance_schema.metadata_locks ml
JOIN performance_schema.threads t ON t.thread_id = ml.owner_thread_id
WHERE ml.object_type = 'TABLE'
  AND ml.object_schema NOT IN ('performance_schema', 'mysql', 'sys')
  AND t.processlist_id <> CONNECTION_ID()
ORDER BY ml.object_schema, ml.object_name, ml.lock_status DESC;

-- sys has a pre-joined view that also suggests the kill:
SELECT object_schema, object_name,
       waiting_pid, waiting_query, waiting_lock_type, waiting_query_secs,
       blocking_pid, blocking_lock_type, blocking_account,
       sql_kill_blocking_connection
FROM sys.schema_table_lock_waits;

-- For migrations, don't wait forever:
--   SET SESSION lock_wait_timeout = 5;
--   ALTER TABLE ...;
-- or use gh-ost / pt-online-schema-change for big tables.
