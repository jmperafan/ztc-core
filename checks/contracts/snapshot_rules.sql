-- Migrated from dbt-bouncer: check_snapshot_has_unique_key,
-- check_snapshot_strategy.
--
-- A snapshot without a unique key cannot identify the row it is versioning,
-- and an unrecognised strategy silently changes what "changed" means.
--
-- Like models, the snapshot check view withholds the resolved top-level
-- columns (unique_key among them), so both values are read out of the
-- double-encoded `config` string.
WITH resolved AS (
    SELECT
        unique_id,
        JSON_EXTRACT_STRING(config, '$') AS cfg
    FROM {{ info_schema('snapshots') }}
)

SELECT
    unique_id,
    JSON_EXTRACT_STRING(cfg, '$.unique_key') AS unique_key,
    JSON_EXTRACT_STRING(cfg, '$.strategy') AS strategy,
    CASE
        WHEN COALESCE(TRIM(JSON_EXTRACT_STRING(cfg, '$.unique_key')), '') = ''
            THEN 'snapshot has no unique_key'
        WHEN COALESCE(JSON_EXTRACT_STRING(cfg, '$.strategy'), '')
             NOT IN ('check', 'timestamp')
            THEN 'snapshot strategy must be check or timestamp'
    END AS rule_broken
FROM resolved
WHERE COALESCE(TRIM(JSON_EXTRACT_STRING(cfg, '$.unique_key')), '') = ''
   OR COALESCE(JSON_EXTRACT_STRING(cfg, '$.strategy'), '')
      NOT IN ('check', 'timestamp')
