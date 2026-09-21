-- Migrated from dbt-bouncer: check_exposure_has_owner,
-- check_exposure_based_on_view, check_exposure_based_on_model.
--
-- check_exposure_based_on_non_public_models is already covered by
-- exposures_depend_only_on_public_models, which predates this migration.
--
-- An exposure must not sit on a view (unpredictable cost at query time) and
-- must name a reachable human. The cap on dependencies is a design smell
-- check: an exposure fed by more than five models is usually a dashboard that
-- should be reading one well-defined mart instead.
WITH exposure_deps AS (
    SELECT
        x.unique_id,
        x.owner_name,
        x.owner_email,
        COUNT(DISTINCT m.unique_id) AS n_models,
        COUNT(DISTINCT CASE WHEN m.materialized = 'view'
                            THEN m.unique_id END) AS n_views
    FROM {{ info_schema('exposures') }} AS x
    LEFT JOIN {{ info_schema('edges') }} AS e
        ON e.child_unique_id = x.unique_id
    LEFT JOIN {{ info_schema('models') }} AS m
        ON m.unique_id = e.parent_unique_id
    GROUP BY x.unique_id, x.owner_name, x.owner_email
)

SELECT
    unique_id,
    n_models,
    n_views,
    CASE
        WHEN COALESCE(TRIM(owner_name), '') = ''
             OR COALESCE(TRIM(owner_email), '') = ''
            THEN 'exposure needs both an owner name and email'
        WHEN n_views > 0
            THEN 'exposure depends on a view'
        WHEN n_models > 5
            THEN 'exposure depends on more than 5 models'
    END AS rule_broken
FROM exposure_deps
WHERE COALESCE(TRIM(owner_name), '') = ''
   OR COALESCE(TRIM(owner_email), '') = ''
   OR n_views > 0
   OR n_models > 5
