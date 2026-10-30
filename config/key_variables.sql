-- key_variables.sql
-- The settings that matter most for performance and durability, in one list,
-- plus everything changed from compiled default and where the value came from.

SELECT variable_name, variable_value
FROM performance_schema.global_variables
WHERE variable_name IN (
    'innodb_buffer_pool_size', 'innodb_buffer_pool_instances',
    'innodb_redo_log_capacity', 'innodb_log_file_size',
    'innodb_flush_log_at_trx_commit', 'sync_binlog', 'innodb_flush_method',
    'innodb_io_capacity', 'innodb_io_capacity_max',
    'innodb_file_per_table', 'innodb_dedicated_server',
    'max_connections', 'thread_cache_size', 'table_open_cache', 'table_definition_cache',
    'tmp_table_size', 'max_heap_table_size', 'temptable_max_ram',
    'sort_buffer_size', 'join_buffer_size',
    'transaction_isolation', 'binlog_format', 'gtid_mode',
    'max_allowed_packet', 'wait_timeout', 'lock_wait_timeout', 'innodb_lock_wait_timeout',
    'long_query_time', 'slow_query_log', 'performance_schema'
)
ORDER BY variable_name;

-- where every non-default value came from (COMPILED / GLOBAL / EXPLICIT / PERSISTED / DYNAMIC ...)
SELECT vi.variable_name, gv.variable_value, vi.variable_source, vi.variable_path,
       vi.set_time, vi.set_user, vi.set_host
FROM performance_schema.variables_info vi
JOIN performance_schema.global_variables gv USING (variable_name)
WHERE vi.variable_source <> 'COMPILED'
ORDER BY vi.variable_source, vi.variable_name;

-- persisted with SET PERSIST (lives in mysqld-auto.cnf, overrides my.cnf!)
SELECT * FROM performance_schema.persisted_variables;
