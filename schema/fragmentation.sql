-- fragmentation.sql
-- Tables with a lot of free space inside their tablespace (after big deletes).
-- data_free is an estimate, and InnoDB will reuse the space for new rows anyway,
-- so only rebuild when you need the disk back or the table is mostly empty.

SET SESSION information_schema_stats_expiry = 0;

SELECT
    table_schema,
    table_name,
    ROUND((data_length + index_length) / 1024 / 1024) AS used_mb,
    ROUND(data_free / 1024 / 1024)                    AS free_mb,
    ROUND(100 * data_free / NULLIF(data_length + index_length + data_free, 0), 1) AS free_pct,
    CONCAT('ALTER TABLE `', table_schema, '`.`', table_name, '` ENGINE=InnoDB, ALGORITHM=INPLACE, LOCK=NONE;') AS rebuild
FROM information_schema.tables
WHERE engine = 'InnoDB'
  AND data_free > 100 * 1024 * 1024
  AND table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
ORDER BY data_free DESC
LIMIT 25;

-- Notes
--  * OPTIMIZE TABLE on InnoDB = ALTER TABLE ... ENGINE=InnoDB (online rebuild + analyze)
--  * the rebuild needs free disk roughly equal to the table size
--  * on a replica-heavy setup the rebuild replicates and causes lag; consider
--    pt-online-schema-change --alter "ENGINE=InnoDB" or gh-ost to throttle it
--  * tables in the shared system tablespace (ibdata1) never give space back to the OS
