-- Migrated from dbt-checkpoint: check-model-columns-have-desc,
-- check-source-columns-have-desc.
--
-- Also replaces the dbt-bouncer catalog_checks equivalents
-- (check_columns_are_all_documented, check_column_description_populated),
-- which were never enabled here: those live in catalog_checks and need
-- target/catalog.json from `dbt docs generate`, which no gate in this repo
-- produces. The dbt Information Schema carries column descriptions at
-- parse time, so the rule is finally enforceable without a warehouse
-- round-trip or a docs build.
SELECT
    c.node_unique_id,
    c.column_name
FROM {{ info_schema('node_columns') }} AS c
WHERE COALESCE(TRIM(c.description), '') = ''
  AND (
        c.node_unique_id LIKE 'model.ztc_core.%'
     OR c.node_unique_id LIKE 'source.ztc_core.%'
     OR c.node_unique_id LIKE 'snapshot.ztc_core.%'
  )
