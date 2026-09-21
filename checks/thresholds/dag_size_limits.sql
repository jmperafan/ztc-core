-- Migrated from dbt-bouncer: check_model_max_fanout,
-- check_model_max_upstream_dependencies.
--
-- Split out of lineage_layer_rules deliberately. Everything in that file is
-- an invariant — there is no correct number of times core may read staging.
-- These two are *thresholds*: the numbers are judgement calls that get
-- revisited as the project grows, and judgement calls are exactly what tends
-- to need `severity: warn` while the debt is worked down. Severity is a
-- per-check-file property in dbt v2, so a threshold sharing a file with an
-- invariant can never be demoted on its own.
--
-- Current values, and why:
--   fanout 8   — dim_members is a conformed hub read by the reservations
--                pipeline plus the coaching/billing/retail facts. It sits at
--                exactly 8 today, so this is a live ceiling, not slack.
--   upstream 5 — a model that joins half the project is one nobody can
--                reason about.
WITH fanout AS (
    SELECT
        m.unique_id,
        COUNT(DISTINCT child.unique_id) AS n,
        'more than 8 downstream models' AS rule_broken
    FROM {{ info_schema('models') }} AS m
    INNER JOIN {{ info_schema('edges') }} AS e
        ON e.parent_unique_id = m.unique_id
    INNER JOIN {{ info_schema('models') }} AS child
        ON child.unique_id = e.child_unique_id
    GROUP BY m.unique_id
    HAVING COUNT(DISTINCT child.unique_id) > 8
),

upstream_load AS (
    SELECT
        child.unique_id,
        COUNT(DISTINCT e.parent_unique_id) AS n,
        'more than 5 upstream models' AS rule_broken
    FROM {{ info_schema('edges') }} AS e
    INNER JOIN {{ info_schema('models') }} AS child
        ON child.unique_id = e.child_unique_id
    INNER JOIN {{ info_schema('models') }} AS parent
        ON parent.unique_id = e.parent_unique_id
    GROUP BY child.unique_id
    HAVING COUNT(DISTINCT e.parent_unique_id) > 5
)

SELECT unique_id, n, rule_broken FROM fanout
UNION ALL
SELECT unique_id, n, rule_broken FROM upstream_load
