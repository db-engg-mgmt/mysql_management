-- users_audit.sql
-- Account review: empty passwords, wildcard hosts, old auth plugins,
-- accounts with global privileges, locked/expired accounts.

-- everything at a glance
SELECT user, host, plugin, account_locked, password_expired,
       password_last_changed, password_lifetime,
       authentication_string = '' AS empty_password
FROM mysql.user
ORDER BY user, host;

-- risky: empty password, or any-host + powerful
SELECT user, host, plugin
FROM mysql.user
WHERE (authentication_string = '' AND plugin NOT IN ('auth_socket', 'unix_socket'))
   OR user = '';

-- mysql_native_password is deprecated in 8.0, disabled by default in 8.4, gone in 9.0
SELECT user, host
FROM mysql.user
WHERE plugin = 'mysql_native_password';

-- accounts with global (*.*) privileges beyond the basics
SELECT grantee, GROUP_CONCAT(privilege_type ORDER BY privilege_type) AS global_privs
FROM information_schema.user_privileges
WHERE privilege_type NOT IN ('USAGE')
GROUP BY grantee
HAVING SUM(privilege_type IN ('SUPER', 'FILE', 'PROCESS', 'SHUTDOWN', 'CREATE USER',
                              'GRANT OPTION', 'RELOAD', 'ALL PRIVILEGES')) > 0
ORDER BY grantee;

-- dynamic privileges (8.0): SYSTEM_VARIABLES_ADMIN, BINLOG_ADMIN, CONNECTION_ADMIN, ...
SELECT user, host, priv, with_grant_option
FROM mysql.global_grants
WHERE user NOT IN ('mysql.session', 'mysql.sys', 'mysql.infoschema')
ORDER BY user, priv;

-- wildcard hosts
SELECT user, host FROM mysql.user WHERE host IN ('%', '') ORDER BY user;

-- roles and who has them
SELECT from_user AS role, from_host, to_user AS granted_to, to_host, with_admin_option
FROM mysql.role_edges;

-- To see one account in full:  SHOW GRANTS FOR 'app'@'10.%';
-- Lock rather than drop while you confirm nobody uses it:  ALTER USER 'old'@'%' ACCOUNT LOCK;
