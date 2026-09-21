-- Migrated from dbt-bouncer: check_macro_code_does_not_contain_regexp_pattern,
-- check_macro_max_number_of_lines, check_macro_max_number_of_arguments.
--
-- Macros are the one resource type whose source the check view does expose
-- (macro_sql). Models are not: the check view has no raw_code column, so the
-- model-side equivalents of these rules are local pre-commit hooks instead.
-- That split is documented in checks/_checks.yml.
WITH project_macros AS (
    SELECT unique_id, name, macro_sql, arguments
    FROM {{ info_schema('macros') }}
    WHERE package_name = 'ztc_core'
      AND name NOT LIKE 'snapshot\_%' ESCAPE '\'
)

SELECT
    unique_id,
    name,
    CASE
        WHEN REGEXP_MATCHES(macro_sql, '(?i)(TODO|FIXME|HACK|XXX)')
            THEN 'unfinished-work marker left in macro'
        WHEN LEN(STR_SPLIT(macro_sql, CHR(10))) > 50
            THEN 'macro longer than 50 lines'
        WHEN COALESCE(JSON_ARRAY_LENGTH(arguments), 0) > 5
            THEN 'macro takes more than 5 arguments'
    END AS rule_broken
FROM project_macros
WHERE REGEXP_MATCHES(macro_sql, '(?i)(TODO|FIXME|HACK|XXX)')
   OR LEN(STR_SPLIT(macro_sql, CHR(10))) > 50
   OR COALESCE(JSON_ARRAY_LENGTH(arguments), 0) > 5
