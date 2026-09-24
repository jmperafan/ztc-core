-- Migrated from dbt-bouncer: check_model_schema_name.
--
-- Target-dependent: dev schemas are prefixed (dbt_jperafan_core), so the
-- pattern is anchored on the suffix only — same reasoning as the bouncer rule.
SELECT
    unique_id,
    schema_name
FROM {{ info_schema('models') }}
WHERE NOT REGEXP_MATCHES(schema_name, '.*(staging|intermediate|core)$')
