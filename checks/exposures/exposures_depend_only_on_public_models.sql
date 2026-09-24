-- Tier 1 — what the business is allowed to point at.
--
-- An exposure is a promise to something outside dbt: a dashboard, a sheet, an
-- application. If that promise is wired to a staging or intermediate model,
-- a refactor of an internal model silently breaks a BI tool, and nothing in
-- the DAG says so. Exposures may only depend on the public core layer.
--
-- Snapshots are permitted: snap_club_members is a governed SCD2 resource, not
-- an internal staging step.
SELECT
    e.child_unique_id AS exposure_unique_id,
    e.parent_unique_id AS depends_on
FROM {{ info_schema('edges') }} AS e
INNER JOIN {{ info_schema('models') }} AS m
    ON m.unique_id = e.parent_unique_id
WHERE e.child_unique_id LIKE 'exposure.%'
  AND m.access != 'public'
