-- applier_lag.sql
-- Replication lag and errors from performance_schema (8.0+).
-- More reliable than Seconds_Behind_Source, and shows per-worker detail with
-- multi-threaded replication. Run on the replica.

-- connection (IO) thread
SELECT channel_name, service_state, source_uuid,
       last_error_number, last_error_message, last_error_timestamp,
       last_heartbeat_timestamp,
       last_queued_transaction,
       TIMESTAMPDIFF(MICROSECOND, last_queued_transaction_original_commit_timestamp,
                     last_queued_transaction_end_queue_timestamp) / 1e6 AS last_queue_lag_s
FROM performance_schema.replication_connection_status;

-- applier per worker: how far behind the source's commit time the last applied trx was
SELECT
    w.channel_name,
    w.worker_id,
    w.service_state,
    w.last_applied_transaction,
    TIMESTAMPDIFF(MICROSECOND, w.last_applied_transaction_original_commit_timestamp,
                  w.last_applied_transaction_end_apply_timestamp) / 1e6 AS applied_lag_s,
    w.applying_transaction,
    TIMESTAMPDIFF(SECOND, w.applying_transaction_start_apply_timestamp, NOW(6)) AS applying_for_s,
    w.last_error_number,
    w.last_error_message
FROM performance_schema.replication_applier_status_by_worker w
ORDER BY w.channel_name, w.worker_id;

-- coordinator (MTA)
SELECT channel_name, service_state, last_error_number, last_error_message,
       last_processed_transaction, processing_transaction
FROM performance_schema.replication_applier_status_by_coordinator;

SELECT @@replica_parallel_workers, @@replica_preserve_commit_order;
-- (pre 8.0.26 names: slave_parallel_workers etc.)
-- On 8.0 also check @@replica_parallel_type (LOGICAL_CLOCK) and, on the source,
-- @@binlog_transaction_dependency_tracking = WRITESET. Both were removed in 8.4,
-- where that behaviour is the only option.

-- One worker always busy and the rest idle = a single huge transaction, or a table
-- without a PK being updated row by row (indexes/tables_without_pk.sql).
