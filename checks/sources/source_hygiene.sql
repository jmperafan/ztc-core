-- Migrated from dbt-bouncer: check_source_freshness_populated,
-- check_source_loader_populated, check_duplicate_sources,
-- check_source_not_orphaned, check_source_min_downstream_models,
-- check_source_used_by_only_one_model,
-- check_source_used_by_models_in_same_directory.
--
-- Sources are the project's contract with the outside world. Each one has to
-- say how it arrives (loader), how stale it may be (freshness), be read by
-- exactly one staging model (the 1:1 mirror), and not be declared twice.
--
-- The check view does not expose the top-level `freshness` column, so the
-- freshness policy is read out of `config` (double-encoded, hence the nested
-- JSON_EXTRACT_STRING) with loaded_at_field as the fallback signal.
WITH usage AS (
    SELECT
        s.unique_id,
        s.source_name,
        s.name,
        s.loader,
        s.loaded_at_field,
        JSON_EXTRACT_STRING(JSON_EXTRACT_STRING(s.config, '$'), '$.freshness') AS freshness,
        s.database_name,
        s.schema_name,
        s.identifier,
        COUNT(DISTINCT m.unique_id) AS n_consumers,
        COUNT(DISTINCT CASE WHEN m.original_file_path NOT LIKE 'models/staging/%'
                            THEN m.unique_id END) AS n_non_staging_consumers
    FROM {{ info_schema('sources') }} AS s
    LEFT JOIN {{ info_schema('edges') }} AS e
        ON e.parent_unique_id = s.unique_id
    LEFT JOIN {{ info_schema('models') }} AS m
        ON m.unique_id = e.child_unique_id
    GROUP BY s.unique_id, s.source_name, s.name, s.loader, s.loaded_at_field,
             JSON_EXTRACT_STRING(JSON_EXTRACT_STRING(s.config, '$'), '$.freshness'),
             s.database_name, s.schema_name, s.identifier
),

duplicates AS (
    SELECT database_name, schema_name, identifier
    FROM {{ info_schema('sources') }}
    GROUP BY database_name, schema_name, identifier
    HAVING COUNT(*) > 1
)

SELECT
    u.unique_id,
    u.n_consumers,
    CASE
        WHEN COALESCE(TRIM(u.loader), '') = ''
            THEN 'source does not say how it is loaded'
        WHEN u.freshness IS NULL AND COALESCE(TRIM(u.loaded_at_field), '') = ''
            THEN 'source has neither a freshness policy nor loaded_at_field'
        WHEN u.n_consumers = 0
            THEN 'source is declared but never used'
        WHEN u.n_consumers > 1
            THEN 'source is read by more than one model (breaks the 1:1 mirror)'
        WHEN u.n_non_staging_consumers > 0
            THEN 'source is read from outside models/staging'
        WHEN d.identifier IS NOT NULL
            THEN 'same physical table declared as a source twice'
    END AS rule_broken
FROM usage AS u
LEFT JOIN duplicates AS d
    ON d.database_name = u.database_name
   AND d.schema_name = u.schema_name
   AND d.identifier = u.identifier
WHERE COALESCE(TRIM(u.loader), '') = ''
   OR (u.freshness IS NULL AND COALESCE(TRIM(u.loaded_at_field), '') = '')
   OR u.n_consumers != 1
   OR u.n_non_staging_consumers > 0
   OR d.identifier IS NOT NULL
