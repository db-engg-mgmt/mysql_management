-- explain_template.sql
-- Capturing a plan for a slow query. Paste the query where marked.

-- estimated plan, tree format is easier to read than the classic table (8.0.16+)
EXPLAIN FORMAT=TREE
SELECT 1;   -- <<< query here

-- actually runs it and shows real rows / loops / time per step (8.0.18+)
-- careful: this EXECUTES the query. For UPDATE/DELETE wrap in a transaction and roll back.
EXPLAIN ANALYZE
SELECT 1;   -- <<< query here

-- optimizer trace when you need to know *why* it picked a plan
-- SET optimizer_trace = 'enabled=on';
-- SELECT ...;
-- SELECT trace FROM information_schema.optimizer_trace\G
-- SET optimizer_trace = 'enabled=off';

-- What to look for:
--  * type=ALL / "Table scan" on a big table
--  * rows estimate wildly different from actual -> ANALYZE TABLE, or histograms:
--      ANALYZE TABLE t UPDATE HISTOGRAM ON col WITH 100 BUCKETS;
--  * "Using temporary; Using filesort" on a large result
--  * index used but key_len shows only part of a composite index used
--  * dependent subquery executed per row
