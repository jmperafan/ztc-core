-- Migrated from dbt-bouncer: check_model_names (x3), check_model_file_name,
-- check_snapshot_names, check_source_names, check_seed_names,
-- check_macro_name_matches_file_name.
--
-- One query replaces seven bouncer rules because the layer prefix and the file
-- name pattern are the same kind of assertion applied to different rows.
-- Each violation reports which convention it broke rather than just failing.
--
-- The macro arm was dead weight under bouncer (filenames did not match macro
-- names, so the rule sat commented out) and is live now that macros/ has been
-- renamed to satisfy it. It assumes one macro per file, which is the
-- convention it exists to hold: a second macro in a file would be reported
-- against that file's name.
WITH resources AS (
    SELECT unique_id, name, original_file_path FROM {{ info_schema('models') }}
    UNION ALL
    SELECT unique_id, name, original_file_path FROM {{ info_schema('snapshots') }}
    UNION ALL
    SELECT unique_id, name, original_file_path FROM {{ info_schema('seeds') }}
    UNION ALL
    -- Project macros only. Package macros are not ours to name, and dbt
    -- generates a snapshot_<name> macro per snapshot with no file of its own.
    SELECT unique_id, name, original_file_path
    FROM {{ info_schema('macros') }}
    WHERE package_name = 'ztc_core'
      AND name NOT LIKE 'snapshot\_%' ESCAPE '\'
),

violations AS (
    SELECT
        unique_id,
        name,
        CASE
            WHEN original_file_path LIKE 'models/staging/%'
                AND NOT REGEXP_MATCHES(name, '^stg_')
                THEN 'staging models must be named stg_*'
            WHEN original_file_path LIKE 'models/intermediate/%'
                AND NOT REGEXP_MATCHES(name, '^(int_|bridge_)')
                THEN 'intermediate models must be named int_* or bridge_*'
            WHEN original_file_path LIKE 'models/core/%'
                AND NOT REGEXP_MATCHES(name, '^(fct_|dim_|bridge_)')
                THEN 'core models must be named fct_*, dim_* or bridge_*'
            WHEN original_file_path LIKE 'snapshots/%'
                AND NOT REGEXP_MATCHES(name, '^snap_')
                THEN 'snapshots must be named snap_*'
            WHEN original_file_path LIKE 'seeds/%'
                AND NOT REGEXP_MATCHES(name, '^seed_')
                THEN 'seeds must be named seed_*'
            WHEN original_file_path LIKE 'macros/%'
                AND REGEXP_EXTRACT(original_file_path, '[^/]+$') != name || '.sql'
                THEN 'macro file name must match the macro it defines'
            -- File name must be lower snake case and match nothing exotic.
            WHEN NOT REGEXP_MATCHES(
                    REGEXP_EXTRACT(original_file_path, '[^/]+$'),
                    '^[a-z][a-z0-9_]*\.(sql|csv)$')
                THEN 'file name must be lower_snake_case'
            ELSE NULL
        END AS rule_broken
    FROM resources
)

SELECT unique_id, name, rule_broken
FROM violations
WHERE rule_broken IS NOT NULL
