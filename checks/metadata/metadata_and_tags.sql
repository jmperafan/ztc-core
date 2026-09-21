-- Migrated from dbt-bouncer: check_model_has_meta_keys (x2),
-- check_model_has_tags, check_source_has_meta_keys, check_source_has_tags.
--
-- Mirrors the +meta and +tags blocks in dbt_project.yml. Declaring it in both
-- places is deliberate: the project file sets the default, this stops a
-- per-model override from dropping it.
WITH tagged AS (
    SELECT
        unique_id,
        original_file_path,
        meta,
        tags,
        'model' AS kind
    FROM {{ info_schema('models') }}
    UNION ALL
    SELECT unique_id, original_file_path, meta, tags, 'source'
    FROM {{ info_schema('sources') }}
)

SELECT
    unique_id,
    kind,
    CASE
        WHEN COALESCE(TRIM(JSON_EXTRACT_STRING(meta, '$.owner')), '') = ''
            THEN 'missing meta.owner'
        WHEN kind = 'model' AND original_file_path LIKE 'models/core/%'
            AND COALESCE(TRIM(JSON_EXTRACT_STRING(meta, '$.sla')), '') = ''
            THEN 'core model missing meta.sla'
        WHEN kind = 'model' AND original_file_path LIKE 'models/core/%'
            AND NOT LIST_CONTAINS(tags, 'core')
            THEN 'core model missing the core tag'
        WHEN kind = 'source' AND NOT LIST_CONTAINS(tags, 'raw')
            THEN 'source missing the raw tag'
    END AS rule_broken
FROM tagged
WHERE COALESCE(TRIM(JSON_EXTRACT_STRING(meta, '$.owner')), '') = ''
   OR (kind = 'model' AND original_file_path LIKE 'models/core/%'
       AND (COALESCE(TRIM(JSON_EXTRACT_STRING(meta, '$.sla')), '') = ''
            OR NOT LIST_CONTAINS(tags, 'core')))
   OR (kind = 'source' AND NOT LIST_CONTAINS(tags, 'raw'))
