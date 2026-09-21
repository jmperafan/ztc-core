-- Migrated from dbt-bouncer: check_model_columns_have_types.
--
-- A contract without declared types is not a contract. Core models are the
-- published surface, so every column they expose must state its type in YAML.
--
-- Related history worth not relearning: these types must be exact. Declaring
-- a generic `number` resolves to NUMBER(38,0), which drifts from the real
-- column precision on each incremental insert and trips
-- on_schema_change=fail. See fusion-contract-numeric-types.
SELECT
    c.node_unique_id,
    c.column_name
FROM {{ info_schema('node_columns') }} AS c
INNER JOIN {{ info_schema('models') }} AS m
    ON m.unique_id = c.node_unique_id
WHERE m.original_file_path LIKE 'models/core/%'
  AND COALESCE(TRIM(c.data_type_declared), '') = ''
