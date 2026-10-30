-- slow_log_setup.sql
-- Turn the slow query log on at runtime (also add to my.cnf so it survives restart).
-- Then digest it with pt-query-digest:
--   pt-query-digest /var/lib/mysql/$(hostname)-slow.log > slow_report.txt
--   pt-query-digest --since '1h' --limit 20 slow.log

SELECT @@slow_query_log, @@slow_query_log_file, @@long_query_time,
       @@log_queries_not_using_indexes, @@log_slow_extra, @@min_examined_row_limit;

-- SET GLOBAL slow_query_log = ON;
-- SET GLOBAL long_query_time = 1;                -- seconds, decimals allowed (0.2)
-- SET GLOBAL log_slow_extra = ON;                -- 8.0.14+, adds rows examined/sent, tmp tables, etc.
-- SET GLOBAL log_queries_not_using_indexes = OFF; -- noisy, leave off unless hunting
-- SET GLOBAL log_throttle_queries_not_using_indexes = 60;

-- Note: long_query_time set via SET GLOBAL only applies to *new* connections.
-- Pooled app connections keep the old value until they reconnect.

-- my.cnf
-- [mysqld]
-- slow_query_log = 1
-- slow_query_log_file = /var/log/mysql/slow.log
-- long_query_time = 1
-- log_slow_extra = 1
