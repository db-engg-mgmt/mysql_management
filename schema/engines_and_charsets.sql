-- engines_and_charsets.sql
-- Non-InnoDB tables and non-utf8mb4 columns. Both tend to come up during
-- upgrades, migrations to managed services, and "why are emojis turning into ????".

SELECT table_schema, engine, COUNT(*) AS tables,
       ROUND(SUM(data_length + index_length) / 1024 / 1024) AS mb
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
GROUP BY table_schema, engine
ORDER BY table_schema, engine;

-- MyISAM leftovers: no crash safety, table level locks
SELECT table_schema, table_name, table_rows
FROM information_schema.tables
WHERE engine = 'MyISAM'
  AND table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys');

-- schema / table defaults
SELECT schema_name, default_character_set_name, default_collation_name
FROM information_schema.schemata
WHERE schema_name NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys');

-- text columns not in utf8mb4 (utf8mb3 'utf8' can't store 4 byte chars)
SELECT table_schema, table_name, column_name, column_type, character_set_name, collation_name
FROM information_schema.columns
WHERE character_set_name IS NOT NULL
  AND character_set_name <> 'utf8mb4'
  AND table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
ORDER BY table_schema, table_name;

-- convert a table (rebuilds it, check index length limits on VARCHAR(255) keys first):
--   ALTER TABLE t CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
