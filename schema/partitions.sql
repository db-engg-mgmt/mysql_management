-- partitions.sql
-- Partitioned tables, partition bounds and row estimates.
--   mysql -e "SET @db='appdb'; SOURCE schema/partitions.sql"

SET @db = COALESCE(@db, DATABASE());

SELECT table_schema, table_name, partition_method, partition_expression,
       COUNT(*) AS partitions,
       SUM(table_rows) AS est_rows,
       ROUND(SUM(data_length + index_length) / 1024 / 1024) AS mb
FROM information_schema.partitions
WHERE partition_name IS NOT NULL
  AND table_schema NOT IN ('mysql', 'sys')
GROUP BY table_schema, table_name, partition_method, partition_expression
ORDER BY mb DESC;

SELECT table_name, partition_name, partition_ordinal_position AS pos,
       partition_description AS upper_bound, table_rows,
       ROUND((data_length + index_length) / 1024 / 1024) AS mb
FROM information_schema.partitions
WHERE table_schema = @db
  AND partition_name IS NOT NULL
ORDER BY table_name, partition_ordinal_position;

-- rows piling into a MAXVALUE catch-all partition usually means the job that
-- adds future partitions stopped. Split it:
--   ALTER TABLE events REORGANIZE PARTITION pmax INTO (
--     PARTITION p202612 VALUES LESS THAN (TO_DAYS('2027-01-01')),
--     PARTITION pmax VALUES LESS THAN MAXVALUE);
-- drop old data instantly instead of DELETE:
--   ALTER TABLE events DROP PARTITION p202501;
