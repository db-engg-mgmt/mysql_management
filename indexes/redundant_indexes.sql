-- redundant_indexes.sql
-- Indexes that are duplicates of, or a left prefix of, another index.
-- sys.schema_redundant_indexes does the work and even writes the DROP for you.
-- pt-duplicate-key-checker is the other option and catches a few more cases
-- (e.g. a secondary index that ends with the PK columns, which InnoDB appends anyway).

SELECT
    table_schema,
    table_name,
    redundant_index_name,
    redundant_index_columns,
    dominant_index_name,
    dominant_index_columns,
    subpart_exists,
    sql_drop_index
FROM sys.schema_redundant_indexes
ORDER BY table_schema, table_name;

-- Things to double check before dropping:
--  * the "redundant" one may be UNIQUE and the dominant one not -> keep it
--  * a FK may depend on it; InnoDB will refuse the drop if nothing else covers the FK
--  * index hints in application code (FORCE INDEX (idx_name)) will error if it's gone
