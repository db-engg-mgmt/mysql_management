-- auto_increment_capacity.sql
-- How close each AUTO_INCREMENT column is to the max of its data type.
-- A signed INT PK running out at 2,147,483,647 gives "Duplicate entry" errors on every insert.

SET SESSION information_schema_stats_expiry = 0;

SELECT
    t.table_schema,
    t.table_name,
    c.column_name,
    c.column_type,
    t.auto_increment,
    CASE
        WHEN c.data_type = 'tinyint'   THEN 255
        WHEN c.data_type = 'smallint'  THEN 65535
        WHEN c.data_type = 'mediumint' THEN 16777215
        WHEN c.data_type = 'int'       THEN 4294967295
        WHEN c.data_type = 'bigint'    THEN 18446744073709551615
    END >> IF(c.column_type LIKE '%unsigned%', 0, 1) AS max_value,
    ROUND(100 * t.auto_increment /
        (CASE
            WHEN c.data_type = 'tinyint'   THEN 255
            WHEN c.data_type = 'smallint'  THEN 65535
            WHEN c.data_type = 'mediumint' THEN 16777215
            WHEN c.data_type = 'int'       THEN 4294967295
            WHEN c.data_type = 'bigint'    THEN 18446744073709551615
         END >> IF(c.column_type LIKE '%unsigned%', 0, 1)), 2) AS pct_used
FROM information_schema.tables t
JOIN information_schema.columns c
  ON c.table_schema = t.table_schema
 AND c.table_name   = t.table_name
 AND c.extra LIKE '%auto_increment%'
WHERE t.auto_increment IS NOT NULL
  AND t.table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
ORDER BY pct_used DESC
LIMIT 25;

-- sys has a view for this too: SELECT * FROM sys.schema_auto_increment_columns LIMIT 20;
