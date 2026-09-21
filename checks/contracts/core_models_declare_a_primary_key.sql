-- Tier 1 — grain.
--
-- Every core model is contracted, and a contract without a declared primary
-- key documents column types but says nothing about grain. This project
-- declares PKs at column level (with warn_unenforced: false, which is what
-- silences dbt1109 on Snowflake) rather than in a model-level constraints
-- block, so read the resolved primary_key list rather than constraints.
SELECT
    unique_id,
    primary_key
FROM {{ info_schema('models') }}
WHERE original_file_path LIKE 'models/core/%'
  AND (primary_key IS NULL OR LEN(primary_key) = 0)
