-- Migrated from dbt-bouncer: check_lineage_permitted_upstream_models (x3),
-- check_lineage_seed_cannot_be_used, check_lineage_source_cannot_be_used.
--
-- The layering rule in one place: staging reads sources only; intermediate
-- reads staging/intermediate but never core; core reads intermediate/core but
-- never staging directly. Core is the published layer — an intermediate model
-- reading from it makes core load-order-sensitive and risks a cycle.
--
-- These are invariants, not thresholds: there is no defensible value of
-- "sometimes core reads staging". The tunable ceilings that used to live in
-- this file (max fanout, max upstream dependencies) are in
-- checks/thresholds/dag_size_limits.sql so their severity can be moved
-- without touching anything here.
WITH parent_layers AS (
    SELECT
        child.unique_id AS child_id,
        child.original_file_path AS child_path,
        parent.original_file_path AS parent_path,
        e.parent_unique_id
    FROM {{ info_schema('edges') }} AS e
    INNER JOIN {{ info_schema('models') }} AS child
        ON child.unique_id = e.child_unique_id
    LEFT JOIN {{ info_schema('models') }} AS parent
        ON parent.unique_id = e.parent_unique_id
)

SELECT
    child_id AS unique_id,
    parent_unique_id AS offending_parent,
    CASE
        WHEN child_path LIKE 'models/staging/%'
             AND parent_path IS NOT NULL
            THEN 'staging may only read sources, not models'
        WHEN child_path LIKE 'models/intermediate/%'
             AND parent_path LIKE 'models/core/%'
            THEN 'intermediate must not read from core'
        WHEN child_path LIKE 'models/core/%'
             AND parent_path LIKE 'models/staging/%'
            THEN 'core must not read staging directly'
        -- Absorbed from the former only_staging_reads_sources check: sources
        -- enter the project through models/staging and nowhere else.
        WHEN parent_unique_id LIKE 'source.%'
             AND child_path NOT LIKE 'models/staging/%'
            THEN 'only staging may read a source'
        WHEN parent_unique_id LIKE 'seed.%'
            THEN 'models must not read seeds'
    END AS rule_broken
FROM parent_layers
WHERE (child_path LIKE 'models/staging/%' AND parent_path IS NOT NULL)
   OR (child_path LIKE 'models/intermediate/%' AND parent_path LIKE 'models/core/%')
   OR (child_path LIKE 'models/core/%' AND parent_path LIKE 'models/staging/%')
   OR (parent_unique_id LIKE 'source.%' AND child_path NOT LIKE 'models/staging/%')
   OR parent_unique_id LIKE 'seed.%'
