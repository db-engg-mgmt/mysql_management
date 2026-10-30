-- memory_usage.sql
-- Where is mysqld's memory going. Useful when RSS is far above
-- innodb_buffer_pool_size and you're worried about the OOM killer.
-- Memory instruments are on by default in 8.0.

SELECT * FROM sys.memory_global_total;

SELECT event_name, current_count, current_alloc, current_avg_alloc, high_alloc
FROM sys.memory_global_by_current_bytes
LIMIT 20;

-- per connection / thread
SELECT thread_id, user, current_count_used, current_allocated, current_max_alloc
FROM sys.memory_by_thread_by_current_bytes
LIMIT 15;

-- per-session buffers that multiply by connection count
SELECT
    @@max_connections,
    @@sort_buffer_size / 1024        AS sort_buffer_kb,
    @@join_buffer_size / 1024        AS join_buffer_kb,
    @@read_buffer_size / 1024        AS read_buffer_kb,
    @@read_rnd_buffer_size / 1024    AS read_rnd_buffer_kb,
    @@tmp_table_size / 1024 / 1024   AS tmp_table_mb,
    @@max_heap_table_size / 1024 / 1024 AS max_heap_mb,
    @@temptable_max_ram / 1024 / 1024   AS temptable_max_ram_mb,
    @@thread_stack / 1024            AS thread_stack_kb;

-- Common culprits: sort/join buffers set globally to hundreds of MB, temptable
-- engine (memory/temptable/physical_ram), lots of prepared statements never
-- closed, or glibc malloc fragmentation (jemalloc/tcmalloc helps).
