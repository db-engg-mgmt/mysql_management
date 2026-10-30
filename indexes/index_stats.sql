-- index_stats.sql
-- Index sizes, cardinality and how old the persistent stats are, for one schema.
--   mysql -e "SET @db='appdb'; SOURCE indexes/index_stats.sql"

SET @db = COALESCE(@db, DATABASE());

SELECT
    s.table_name,
    s.index_name,
    GROUP_CONCAT(CONCAT(s.column_name, IF(s.sub_part IS NULL, '', CONCAT('(', s.sub_part, ')')))
                 ORDER BY s.seq_in_index) AS cols,
    MAX(s.non_unique) = 0                  AS is_unique,
    MAX(s.cardinality)                     AS cardinality,
    MAX(s.is_visible)                      AS visible,
    MAX(s.index_type)                      AS type
FROM information_schema.statistics s
WHERE s.table_schema = @db
GROUP BY s.table_name, s.index_name
ORDER BY s.table_name, s.index_name;

-- size per index from persistent stats (pages * page size)
SELECT table_name, index_name,
       ROUND(stat_value * @@innodb_page_size / 1024 / 1024, 1) AS size_mb,
       last_update
FROM mysql.innodb_index_stats
WHERE database_name = @db
  AND stat_name = 'size'
ORDER BY stat_value DESC
LIMIT 30;

-- stats older than a week on tables that change a lot -> ANALYZE TABLE
SELECT database_name, table_name, n_rows, last_update
FROM mysql.innodb_table_stats
WHERE database_name = @db
ORDER BY last_update
LIMIT 20;
