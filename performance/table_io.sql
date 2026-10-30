-- table_io.sql
-- Read/write activity and latency per table (performance_schema.table_io_waits_summary_by_table).
-- Good for finding the hot tables when you only know "the database is busy".

SELECT
    object_schema,
    object_name,
    count_read,
    count_write,
    count_fetch,
    count_insert,
    count_update,
    count_delete,
    ROUND(sum_timer_wait / 1e12, 1)       AS total_wait_s,
    ROUND(sum_timer_read / 1e12, 1)       AS read_wait_s,
    ROUND(sum_timer_write / 1e12, 1)      AS write_wait_s
FROM performance_schema.table_io_waits_summary_by_table
WHERE object_schema NOT IN ('mysql', 'performance_schema', 'sys', 'information_schema')
ORDER BY sum_timer_wait DESC
LIMIT 25;

-- table level lock waits (non InnoDB row locks: LOCK TABLES, MyISAM, etc.)
SELECT object_schema, object_name, count_star,
       ROUND(sum_timer_wait / 1e12, 2) AS wait_s
FROM performance_schema.table_lock_waits_summary_by_table
WHERE count_star > 0
  AND object_schema NOT IN ('mysql', 'performance_schema', 'sys')
ORDER BY sum_timer_wait DESC
LIMIT 15;
