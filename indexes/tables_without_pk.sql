-- tables_without_pk.sql
-- InnoDB tables with no primary key. Why it matters:
--  * InnoDB invents a hidden 6 byte row id, global mutex on inserts
--  * row based replication of UPDATE/DELETE does a full scan per row on the replica -> massive lag
--  * Group Replication / InnoDB Cluster refuses them outright
--  * online schema change tools need a PK or unique key
--
-- 8.0.30+: sql_generate_invisible_primary_key = ON adds one automatically for new tables.

SELECT t.table_schema, t.table_name, t.engine, t.table_rows,
       ROUND((t.data_length + t.index_length) / 1024 / 1024, 1) AS size_mb,
       (SELECT GROUP_CONCAT(DISTINCT s.index_name)
          FROM information_schema.statistics s
         WHERE s.table_schema = t.table_schema AND s.table_name = t.table_name
           AND s.non_unique = 0) AS unique_keys_instead
FROM information_schema.tables t
LEFT JOIN information_schema.table_constraints c
       ON c.table_schema = t.table_schema
      AND c.table_name   = t.table_name
      AND c.constraint_type = 'PRIMARY KEY'
WHERE t.table_type = 'BASE TABLE'
  AND c.constraint_name IS NULL
  AND t.table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
ORDER BY size_mb DESC;
