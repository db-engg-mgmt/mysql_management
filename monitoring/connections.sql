-- connections.sql
-- Who's connected, from where, and how close to max_connections.

SELECT
    @@max_connections AS max_conn,
    (SELECT COUNT(*) FROM performance_schema.processlist) AS current_conn,
    ROUND(100 * (SELECT COUNT(*) FROM performance_schema.processlist) / @@max_connections, 1) AS pct_used,
    (SELECT variable_value FROM performance_schema.global_status WHERE variable_name = 'Max_used_connections') AS peak,
    (SELECT variable_value FROM performance_schema.global_status WHERE variable_name = 'Max_used_connections_time') AS peak_at;

SELECT user, SUBSTRING_INDEX(host, ':', 1) AS client, db,
       COUNT(*) AS conns,
       SUM(command = 'Sleep') AS sleeping,
       MAX(time) AS oldest_secs
FROM performance_schema.processlist
GROUP BY user, client, db
ORDER BY conns DESC
LIMIT 30;

-- historic totals per account (since startup / table truncation)
SELECT user, host, current_connections, total_connections
FROM performance_schema.accounts
WHERE user IS NOT NULL
ORDER BY total_connections DESC
LIMIT 20;

-- connection errors broken down (host_cache)
SELECT ip, host, sum_connect_errors, count_authentication_errors,
       count_host_blocked_errors, first_error_seen, last_error_seen
FROM performance_schema.host_cache
WHERE sum_connect_errors > 0 OR count_authentication_errors > 0
ORDER BY last_error_seen DESC;
-- "Host is blocked because of many connection errors" -> FLUSH HOSTS; (or TRUNCATE performance_schema.host_cache on 8.0.23+)
