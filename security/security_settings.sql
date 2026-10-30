-- security_settings.sql
-- Server settings worth checking on any box you inherit.

SELECT
    @@require_secure_transport     AS require_tls,
    @@tls_version,
    @@local_infile                 AS local_infile,         -- should be OFF
    @@secure_file_priv             AS secure_file_priv,     -- NULL or a dedicated dir, never ''
    @@skip_name_resolve,
    @@default_password_lifetime,
    @@log_error_verbosity,
    @@sql_mode;

-- password policy component (8.0)
SELECT * FROM performance_schema.global_variables WHERE variable_name LIKE 'validate_password%';

-- is this connection encrypted, and are others?
SHOW SESSION STATUS LIKE 'Ssl_cipher';
SELECT t.processlist_user AS user, t.processlist_host AS host, s.variable_value AS cipher
FROM performance_schema.status_by_thread s
JOIN performance_schema.threads t ON t.thread_id = s.thread_id
WHERE s.variable_name = 'Ssl_cipher'
  AND t.processlist_user IS NOT NULL
ORDER BY cipher, user;

-- installed plugins / components (audit log, keyring, etc.)
SELECT plugin_name, plugin_status, plugin_type FROM information_schema.plugins
WHERE plugin_type IN ('AUDIT', 'AUTHENTICATION', 'KEYRING') OR plugin_name LIKE '%keyring%';
SELECT * FROM mysql.component;
