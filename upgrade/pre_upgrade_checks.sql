-- pre_upgrade_checks.sql
-- Quick SQL checks before 5.7 -> 8.0 or 8.0 -> 8.4 LTS. The authoritative check is
-- MySQL Shell's upgrade checker, run that too (see upgrade_runbook.md):
--   mysqlsh -- util checkForServerUpgrade root@localhost:3306 --target-version=8.4.3 --output-format=JSON

SELECT @@version, @@version_comment;

-- tables in non-InnoDB engines (MyISAM is still supported but not with partitioning;
-- partitioned MyISAM must be converted before 8.0)
SELECT table_schema, table_name, engine, create_options
FROM information_schema.tables
WHERE engine NOT IN ('InnoDB')
  AND table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys');

-- accounts on mysql_native_password: the plugin is disabled by default in 8.4
-- and removed in 9.x. Switch them to caching_sha2_password (check client drivers first).
SELECT user, host, plugin FROM mysql.user WHERE plugin = 'mysql_native_password';

-- utf8mb3 ('utf8') objects: still work, but utf8 will eventually mean utf8mb4
SELECT table_schema, table_name, column_name, character_set_name
FROM information_schema.columns
WHERE character_set_name = 'utf8mb3'
  AND table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
LIMIT 50;

-- tables without PK (8.4 upgrade is a good moment to fix these, and required for GR)
SELECT t.table_schema, t.table_name
FROM information_schema.tables t
LEFT JOIN information_schema.table_constraints c
  ON c.table_schema = t.table_schema AND c.table_name = t.table_name AND c.constraint_type = 'PRIMARY KEY'
WHERE t.table_type = 'BASE TABLE' AND c.constraint_name IS NULL
  AND t.table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys');

-- FK referencing non-unique or partial keys: disallowed by default in 8.4
-- (restrict_fk_on_non_standard_key = ON)
SELECT kcu.constraint_schema, kcu.table_name, kcu.constraint_name,
       kcu.referenced_table_name, kcu.referenced_column_name
FROM information_schema.key_column_usage kcu
WHERE kcu.referenced_table_name IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM information_schema.statistics s
      WHERE s.table_schema = kcu.referenced_table_schema
        AND s.table_name   = kcu.referenced_table_name
        AND s.column_name  = kcu.referenced_column_name
        AND s.non_unique = 0);

-- variables set in config/persisted that were removed or renamed (8.4 drops e.g.
-- default_authentication_plugin, binlog_transaction_dependency_tracking,
-- the *_master_* / *_slave_* names, expire_logs_days)
SELECT variable_name, variable_source, variable_path
FROM performance_schema.variables_info
WHERE variable_source IN ('GLOBAL', 'PERSISTED', 'EXPLICIT', 'EXTRA')
  AND (variable_name LIKE '%slave%' OR variable_name LIKE '%master%'
       OR variable_name IN ('default_authentication_plugin', 'expire_logs_days',
                            'binlog_transaction_dependency_tracking', 'replica_parallel_type',
                            'log_bin_use_v1_row_events', 'avoid_temporal_upgrade',
                            'show_old_temporals'));

-- reserved keywords used as identifiers trip up apps after upgrade
-- (8.0 added e.g. RANK, GROUPS, LATERAL, FUNCTION... 8.4 adds MANUAL, PARALLEL, QUALIFY, TABLESAMPLE)
SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE UPPER(column_name) IN ('RANK', 'GROUPS', 'LATERAL', 'CUBE', 'ROWS', 'ROW', 'SYSTEM', 'WINDOW',
                             'FUNCTION', 'MANUAL', 'PARALLEL', 'QUALIFY', 'TABLESAMPLE', 'EMPTY')
  AND table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys');
