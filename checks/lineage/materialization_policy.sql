-- Migrated from dbt-bouncer: check_model_materialization_permitted (x3),
-- check_model_materialization_by_fanout.
--
-- Materialization is a layer-level decision, not a per-model preference.
-- `table` is permitted in intermediate, but only as a deliberate exception for
-- high-fanout hubs — which is what the fanout arm below decides. A model three
-- or more other models read gets materialized once rather than recomputed per
-- consumer.
WITH model_fanout AS (
    SELECT
        m.unique_id,
        m.original_file_path,
        m.materialized,
        COUNT(DISTINCT child.unique_id) AS downstream_models
    FROM {{ info_schema('models') }} AS m
    LEFT JOIN {{ info_schema('edges') }} AS e
        ON e.parent_unique_id = m.unique_id
    LEFT JOIN {{ info_schema('models') }} AS child
        ON child.unique_id = e.child_unique_id
    GROUP BY m.unique_id, m.original_file_path, m.materialized
)

SELECT
    unique_id,
    materialized,
    downstream_models,
    CASE
        WHEN original_file_path LIKE 'models/staging/%'
             AND materialized NOT IN ('view')
            THEN 'staging must be a view'
        WHEN original_file_path LIKE 'models/intermediate/%'
             AND materialized NOT IN ('view', 'ephemeral', 'table')
            THEN 'intermediate must be view, ephemeral or table'
        WHEN original_file_path LIKE 'models/core/%'
             AND materialized NOT IN ('table', 'incremental')
            THEN 'core must be table or incremental'
        WHEN downstream_models >= 3 AND materialized = 'view'
            THEN 'read by 3+ models but still a view — materialize it'
    END AS rule_broken
FROM model_fanout
WHERE (original_file_path LIKE 'models/staging/%' AND materialized NOT IN ('view'))
   OR (original_file_path LIKE 'models/intermediate/%'
       AND materialized NOT IN ('view', 'ephemeral', 'table'))
   OR (original_file_path LIKE 'models/core/%'
       AND materialized NOT IN ('table', 'incremental'))
   OR (downstream_models >= 3 AND materialized = 'view')
