-- status_overview.sql
-- One screen server summary from global status. Counters are since startup.

SELECT @@hostname, @@version, @@version_comment, @@read_only, @@super_read_only,
       @@server_id, @@gtid_mode,
       SEC_TO_TIME((SELECT variable_value FROM performance_schema.global_status WHERE variable_name = 'Uptime')) AS uptime;

SELECT
    MAX(CASE WHEN variable_name = 'Threads_connected' THEN variable_value END) AS threads_connected,
    MAX(CASE WHEN variable_name = 'Threads_running'   THEN variable_value END) AS threads_running,
    MAX(CASE WHEN variable_name = 'Max_used_connections' THEN variable_value END) AS max_used_conns,
    @@max_connections                                                         AS max_connections,
    MAX(CASE WHEN variable_name = 'Aborted_connects'  THEN variable_value END) AS aborted_connects,
    MAX(CASE WHEN variable_name = 'Aborted_clients'   THEN variable_value END) AS aborted_clients,
    MAX(CASE WHEN variable_name = 'Connection_errors_max_connections' THEN variable_value END) AS refused_max_conn
FROM performance_schema.global_status;

-- throughput / query mix
SELECT
    variable_name,
    variable_value,
    ROUND(variable_value / (SELECT variable_value FROM performance_schema.global_status WHERE variable_name = 'Uptime'), 1) AS per_sec
FROM performance_schema.global_status
WHERE variable_name IN ('Questions', 'Com_select', 'Com_insert', 'Com_update', 'Com_delete',
                        'Com_commit', 'Com_rollback', 'Slow_queries',
                        'Select_full_join', 'Select_scan', 'Sort_merge_passes',
                        'Created_tmp_tables', 'Created_tmp_disk_tables',
                        'Innodb_row_lock_waits', 'Innodb_deadlocks',
                        'Table_open_cache_misses', 'Table_open_cache_overflows')
ORDER BY variable_name;

-- Things to eyeball:
--   Threads_running consistently > CPU cores -> saturated
--   Created_tmp_disk_tables / Created_tmp_tables high -> tmp tables spilling
--   Select_full_join > 0 and climbing -> joins without usable index
--   Table_open_cache_overflows climbing -> raise table_open_cache
