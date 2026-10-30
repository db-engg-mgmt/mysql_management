-- sizes.sql
-- Schema and table sizes. information_schema numbers are estimates from
-- InnoDB stats (and cached for information_schema_stats_expiry seconds, 86400
-- by default in 8.0!). For fresh numbers in this session:
SET SESSION information_schema_stats_expiry = 0;

SELECT
    table_schema,
    COUNT(*)                                                         AS tables,
    ROUND(SUM(data_length)  / 1024 / 1024 / 1024, 2)                 AS data_gb,
    ROUND(SUM(index_length) / 1024 / 1024 / 1024, 2)                 AS index_gb,
    ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2)   AS total_gb,
    ROUND(SUM(data_free) / 1024 / 1024 / 1024, 2)                    AS free_gb
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
GROUP BY table_schema
ORDER BY total_gb DESC;

SELECT
    table_schema,
    table_name,
    engine,
    row_format,
    table_rows                                              AS est_rows,
    ROUND(data_length / 1024 / 1024, 1)                     AS data_mb,
    ROUND(index_length / 1024 / 1024, 1)                    AS index_mb,
    ROUND((data_length + index_length) / 1024 / 1024, 1)    AS total_mb,
    ROUND(index_length / NULLIF(data_length, 0), 2)         AS idx_to_data
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
ORDER BY data_length + index_length DESC
LIMIT 30;

-- real on-disk file sizes (file-per-table)
SELECT file_name, tablespace_name,
       ROUND(total_extents * extent_size / 1024 / 1024, 1) AS allocated_mb,
       ROUND(data_free / 1024 / 1024, 1) AS free_mb
FROM information_schema.files
WHERE file_type = 'TABLESPACE'
ORDER BY total_extents * extent_size DESC
LIMIT 20;
