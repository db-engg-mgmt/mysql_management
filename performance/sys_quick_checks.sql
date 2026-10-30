-- sys_quick_checks.sql
-- The sys schema views I reach for most, in one place.
-- All formatted for humans; use the x$ versions if you need raw numbers to sort or graph.

-- statements with full table scans
SELECT query, db, exec_count, total_latency, no_index_used_count, rows_examined_avg
FROM sys.statements_with_full_table_scans
ORDER BY no_index_used_count DESC
LIMIT 15;

-- statements creating temp tables on disk
SELECT query, db, exec_count, total_latency, disk_tmp_tables, tmp_tables_to_disk_pct
FROM sys.statements_with_temp_tables
ORDER BY disk_tmp_tables DESC
LIMIT 15;

-- statements doing filesorts
SELECT query, db, exec_count, total_latency, sort_merge_passes, rows_sorted
FROM sys.statements_with_sorting
ORDER BY sort_merge_passes DESC
LIMIT 15;

-- statements erroring / warning a lot
SELECT query, db, exec_count, errors, error_pct, warnings
FROM sys.statements_with_errors_or_warnings
ORDER BY errors DESC
LIMIT 15;

-- 95th percentile runtime offenders
SELECT query, db, exec_count, avg_latency, max_latency
FROM sys.statements_with_runtimes_in_95th_percentile
LIMIT 15;

-- tables with full scans (whole table read via index-less access)
SELECT object_schema, object_name, rows_full_scanned, latency
FROM sys.schema_tables_with_full_table_scans
LIMIT 15;

-- who's using the server (by user / host)
SELECT user, statements, statement_latency, table_scans, file_ios, current_connections, total_connections, current_memory
FROM sys.user_summary
ORDER BY statement_latency DESC;
