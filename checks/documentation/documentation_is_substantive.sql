-- Migrated from dbt-bouncer: check_model_description_populated (min 50),
-- check_model_documentation_coverage (100%), check_source_description_populated
-- (min 30), check_snapshot_description_populated,
-- check_exposure_description_populated, check_macro_description_populated.
--
-- The length floor is the point. A one-word description is worse than none —
-- it looks documented and defeats the coverage metric. Coverage at 100% is
-- implied: a model with no description has length 0 and fails the floor, so a
-- separate coverage rule is redundant once the floor exists.
WITH described AS (
    SELECT unique_id, description, 50 AS min_len, 'model' AS kind
    FROM {{ info_schema('models') }}
    UNION ALL
    SELECT unique_id, description, 30, 'source'
    FROM {{ info_schema('sources') }}
    UNION ALL
    SELECT unique_id, description, 30, 'snapshot'
    FROM {{ info_schema('snapshots') }}
    UNION ALL
    SELECT unique_id, description, 30, 'exposure'
    FROM {{ info_schema('exposures') }}
    UNION ALL
    -- Project macros only. Package macros are not ours to document, and
    -- dbt generates a snapshot_<name> macro per snapshot that has no
    -- description and no place to put one.
    SELECT unique_id, description, 30, 'macro'
    FROM {{ info_schema('macros') }}
    WHERE package_name = 'ztc_core'
      AND name NOT LIKE 'snapshot\_%' ESCAPE '\'
)

SELECT
    unique_id,
    kind,
    LENGTH(COALESCE(TRIM(description), '')) AS description_length,
    min_len AS required_length
FROM described
WHERE LENGTH(COALESCE(TRIM(description), '')) < min_len
