-- unused_indexes.sql
-- Indexes with no reads since server start (or since the p_s tables were truncated).
-- Check uptime first - an index used by the monthly report won't show up after a restart last week.
-- Check replicas too, read traffic may only go there.
--
-- Before dropping, make it invisible for a while (8.0+), so rollback is instant:
--   ALTER TABLE t ALTER INDEX idx INVISIBLE;
--   ... wait a business cycle ...
--   ALTER TABLE t DROP INDEX idx;

SELECT SEC_TO_TIME(variable_value) AS uptime
FROM performance_schema.global_status WHERE variable_name = 'Uptime';

SELECT
    s.object_schema,
    s.object_name                 AS tbl,
    s.index_name,
    s.count_write                 AS writes_maintaining_it,
    ROUND(st.stat_value * @@innodb_page_size / 1024 / 1024, 1) AS size_mb
FROM performance_schema.table_io_waits_summary_by_index_usage s
LEFT JOIN mysql.innodb_index_stats st
       ON st.database_name = s.object_schema
      AND st.table_name   = s.object_name
      AND st.index_name   = s.index_name
      AND st.stat_name    = 'size'
WHERE s.index_name IS NOT NULL
  AND s.index_name <> 'PRIMARY'
  AND s.count_read = 0
  AND s.object_schema NOT IN ('mysql', 'performance_schema', 'sys')
  AND NOT EXISTS (                                          -- keep unique constraints
        SELECT 1 FROM information_schema.statistics x
        WHERE x.table_schema = s.object_schema AND x.table_name = s.object_name
          AND x.index_name = s.index_name AND x.non_unique = 0)
ORDER BY size_mb DESC;

-- same thing, sys flavour:  SELECT * FROM sys.schema_unused_indexes;
