-- Migrated from dbt-bouncer: check_model_grant_privilege_required,
-- check_model_number_of_grants.
--
-- Downstream projects can only read what has been granted, so every core
-- model must grant select. The ceiling on distinct privileges is the other
-- half: a model handing out more than a few is usually a copy-paste accident
-- rather than a decision.
--
-- The double JSON_EXTRACT_STRING is not redundant. The check view does not
-- expose the top-level `grants` column (see checks/_checks.yml for the full
-- list of what it withholds), so grants have to be read out of `config` —
-- and `config` arrives double-encoded, as a JSON *string* containing JSON.
-- The inner call unwraps the string, the outer one reads the field.
WITH resolved AS (
    SELECT
        unique_id,
        original_file_path,
        JSON_EXTRACT_STRING(config, '$') AS cfg
    FROM {{ info_schema('models') }}
)

SELECT
    unique_id,
    JSON_EXTRACT_STRING(cfg, '$.grants') AS grants,
    CASE
        WHEN original_file_path LIKE 'models/core/%'
             AND JSON_EXTRACT_STRING(cfg, '$.grants.select[0]') IS NULL
            THEN 'core model does not grant select'
        WHEN COALESCE(LEN(JSON_KEYS(cfg, '$.grants')), 0) > 3
            THEN 'more than 3 distinct privileges granted'
    END AS rule_broken
FROM resolved
WHERE (original_file_path LIKE 'models/core/%'
       AND JSON_EXTRACT_STRING(cfg, '$.grants.select[0]') IS NULL)
   OR COALESCE(LEN(JSON_KEYS(cfg, '$.grants')), 0) > 3
