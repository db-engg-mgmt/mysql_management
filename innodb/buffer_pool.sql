-- buffer_pool.sql
-- Buffer pool size, hit ratio, dirty pages, free pages, and what's in it.

SELECT
    ROUND(@@innodb_buffer_pool_size / 1024 / 1024 / 1024, 2) AS bp_size_gb,
    @@innodb_buffer_pool_instances                            AS instances,
    @@innodb_buffer_pool_chunk_size / 1024 / 1024             AS chunk_mb;

SELECT
    MAX(CASE WHEN variable_name = 'Innodb_buffer_pool_pages_total' THEN variable_value END) AS pages_total,
    MAX(CASE WHEN variable_name = 'Innodb_buffer_pool_pages_free'  THEN variable_value END) AS pages_free,
    MAX(CASE WHEN variable_name = 'Innodb_buffer_pool_pages_dirty' THEN variable_value END) AS pages_dirty,
    ROUND(100 * MAX(CASE WHEN variable_name = 'Innodb_buffer_pool_pages_dirty' THEN variable_value END)
              / MAX(CASE WHEN variable_name = 'Innodb_buffer_pool_pages_total' THEN variable_value END), 2) AS dirty_pct,
    -- logical reads that had to go to disk
    ROUND(100 * (1 - MAX(CASE WHEN variable_name = 'Innodb_buffer_pool_reads' THEN variable_value END)
                   / NULLIF(MAX(CASE WHEN variable_name = 'Innodb_buffer_pool_read_requests' THEN variable_value END), 0)), 3) AS hit_pct,
    MAX(CASE WHEN variable_name = 'Innodb_buffer_pool_wait_free' THEN variable_value END) AS wait_free
FROM performance_schema.global_status
WHERE variable_name LIKE 'Innodb_buffer_pool%';

-- hit_pct is since startup, so it hides a bad last hour. For the current rate,
-- sample Innodb_buffer_pool_reads twice a minute apart.
-- wait_free > 0 and climbing = page cleaners can't keep up, foreground threads
-- are flushing to get free pages.

-- what's cached, by schema / table (sys view scans the buffer pool, avoid on huge BPs at peak)
SELECT object_schema, allocated, data, pages, pages_hashed, rows_cached
FROM sys.innodb_buffer_stats_by_schema
ORDER BY pages DESC
LIMIT 15;

SELECT object_schema, object_name, allocated, data, pages
FROM sys.innodb_buffer_stats_by_table
ORDER BY pages DESC
LIMIT 20;

-- resizing is online in 8.0 (in chunk multiples):
--   SET GLOBAL innodb_buffer_pool_size = 48 * 1024 * 1024 * 1024;
--   SELECT variable_value FROM performance_schema.global_status WHERE variable_name = 'Innodb_buffer_pool_resize_status';
