-- group_replication.sql
-- InnoDB Cluster / Group Replication member state and certification queue.

SELECT member_host, member_port, member_state, member_role, member_version,
       member_communication_stack
FROM performance_schema.replication_group_members;

-- queue sizes per member. Growing count_transactions_in_queue = this member
-- can't keep up; flow control will start throttling the writer.
SELECT
    m.member_host,
    s.count_transactions_in_queue           AS certify_queue,
    s.count_transactions_remote_in_applier_queue AS apply_queue,
    s.count_transactions_checked,
    s.count_conflicts_detected,
    s.count_transactions_rows_validating,
    s.transactions_committed_all_members
FROM performance_schema.replication_group_member_stats s
JOIN performance_schema.replication_group_members m ON m.member_id = s.member_id;

SELECT @@group_replication_single_primary_mode, @@group_replication_consistency,
       @@group_replication_flow_control_mode, @@group_replication_flow_control_applier_threshold;

-- From mysqlsh:  dba.getCluster().status({extended: 1})
