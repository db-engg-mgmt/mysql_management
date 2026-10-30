-- io_and_flushing.sql
-- InnoDB I/O settings and per-file latency from performance_schema.

SELECT @@innodb_io_capacity, @@innodb_io_capacity_max, @@innodb_flush_method,
       @@innodb_flush_neighbors, @@innodb_page_cleaners, @@innodb_read_io_threads,
       @@innodb_write_io_threads, @@innodb_doublewrite, @@innodb_adaptive_flushing;

-- files with the most I/O wait (sys formats the latencies)
SELECT file, total, total_latency, count_read, read_latency, count_write, write_latency
FROM sys.io_global_by_file_by_latency
LIMIT 20;

-- by wait class
SELECT event_name, total, total_latency, avg_latency, max_latency
FROM sys.io_global_by_wait_by_latency
LIMIT 15;

-- data_written vs pages flushed (since startup)
SELECT variable_name, variable_value
FROM performance_schema.global_status
WHERE variable_name IN ('Innodb_data_reads', 'Innodb_data_writes', 'Innodb_data_fsyncs',
                        'Innodb_data_pending_reads', 'Innodb_data_pending_writes',
                        'Innodb_data_pending_fsyncs', 'Innodb_buffer_pool_pages_flushed',
                        'Innodb_dblwr_writes', 'Innodb_dblwr_pages_written');
