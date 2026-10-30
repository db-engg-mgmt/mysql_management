# MySQL 8.0 -> 8.4 LTS upgrade runbook

8.0 reached end of life in April 2026, so most of what I'm upgrading now is 8.0 -> 8.4.
Same approach works for 5.7 -> 8.0 (that one has more breaking changes, read the
"Changes in MySQL 8.0" upgrade notes first). Note that downgrades are not supported -
the way back is a backup or an old-version replica.

## Before

1. Upgrade checker, fix everything it reports as an error:
   ```bash
   mysqlsh -- util checkForServerUpgrade root@localhost:3306 --target-version=8.4.3
   ```
2. `upgrade/pre_upgrade_checks.sql`
3. Remove/rename removed variables from my.cnf and `mysqld-auto.cnf`
   (`SELECT * FROM performance_schema.persisted_variables`). A removed variable in
   my.cnf = server won't start.
4. App drivers: confirm they support `caching_sha2_password`, or plan to enable
   `mysql_native_password=ON` temporarily on 8.4.
5. Backup, and actually restore it somewhere.
6. Test the upgrade on a restored copy and run the application test suite against it.

## Rolling upgrade (replication)

Upgrade replicas first, source last. A newer replica can replicate from an older source,
not the other way around.

```
replica2 -> replica1 -> promote replica1 (switchover) -> old source becomes a replica -> upgrade it
```

Per server:

```bash
mysql -e "SET GLOBAL innodb_fast_shutdown = 0"     # slow shutdown, clean redo/undo
systemctl stop mysqld
# swap packages (dnf/apt from the 8.4 repo), or swap the tarball basedir
dnf install mysql-community-server-8.4.*
systemctl start mysqld
tail -f /var/log/mysql/error.log                  # data dictionary + system tables upgrade happens here
```

Since 8.0.16 there is no separate `mysql_upgrade` step - the server does it on startup
(`--upgrade=AUTO`).

Check:

```sql
SELECT @@version;
SHOW REPLICA STATUS\G
SELECT * FROM performance_schema.error_log WHERE prio IN ('Error', 'Warning') ORDER BY logged DESC LIMIT 50;
```

## After

- Run `bin/mysql_health_check.sh` and diff against the pre-upgrade report.
- Watch `performance/top_statements.sql` for plan regressions for a day or two. The optimizer
  changes between versions; histograms and `ANALYZE TABLE` on the big tables help.
- Re-enable anything disabled for the window (event scheduler, monitoring checks).

## InnoDB Cluster

Use MySQL Shell: upgrade secondaries one at a time (`dba.getCluster().status()` between each),
then `cluster.setPrimaryInstance()` to move primary, upgrade the old primary, then
`dba.upgradeMetadata()` and upgrade MySQL Router.
