-- top_statements.sql
-- Heaviest statement digests from performance_schema. This is the MySQL
-- equivalent of pg_stat_statements and the first place to look for "what's
-- eating the server". Timer columns are picoseconds.
--
-- Digest table holds performance_schema_digests_size rows (default ~10k); when
-- it's full new digests go into a NULL bucket. Truncate it after a tuning round:
--   TRUNCATE performance_schema.events_statements_summary_by_digest;

SELECT
    schema_name                                       AS db,
    count_star                                        AS calls,
    ROUND(sum_timer_wait / 1e12, 1)                   AS total_s,
    ROUND(avg_timer_wait / 1e9, 2)                    AS avg_ms,
    ROUND(max_timer_wait / 1e9, 1)                    AS max_ms,
    ROUND(100 * sum_timer_wait / SUM(sum_timer_wait) OVER (), 1) AS pct,
    ROUND(sum_lock_time / 1e12, 2)                    AS lock_s,
    sum_rows_examined                                 AS rows_examined,
    sum_rows_sent                                     AS rows_sent,
    ROUND(sum_rows_examined / NULLIF(sum_rows_sent, 0)) AS exam_per_sent,
    sum_no_index_used + sum_no_good_index_used        AS no_index,
    sum_created_tmp_disk_tables                       AS tmp_disk,
    first_seen,
    last_seen,
    LEFT(digest_text, 150)                            AS digest_text,
    digest
FROM performance_schema.events_statements_summary_by_digest
WHERE schema_name IS NOT NULL
ORDER BY sum_timer_wait DESC
LIMIT 25;

-- exam_per_sent in the thousands = scanning a lot to return a little -> index candidate.
-- Get a real example of a digest with literals (needs events_statements_history_long consumer on):
--   SELECT sql_text FROM performance_schema.events_statements_history_long WHERE digest = '<digest>' LIMIT 1;
-- 8.0 also keeps one sample per digest:
--   SELECT query_sample_text FROM performance_schema.events_statements_summary_by_digest WHERE digest = '<digest>';
