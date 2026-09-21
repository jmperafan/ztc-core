-- Migrated from dbt-bouncer: check_model_documented_in_same_directory,
-- check_model_property_file_location, check_macro_property_file_location.
--
-- Layer-scoped property files mean you can always guess which file documents
-- a given model: the YAML sits beside the SQL it describes. A model documented
-- from another layer's file is how property files drift into one unnavigable
-- 2,000-line YAML.
--
-- Note on the REGEXP_REPLACE: the info schema serialises
-- properties_yml_file_path differently per resource type. Models get a plain
-- repo-relative path; macros get one prefixed with the package, as in
-- 'ztc_core://tests/generic/_generic_tests__macros.yml'. Stripping the
-- '<pkg>://' first is what makes the two comparable — without it every
-- macro looks misplaced.
WITH resources AS (
    SELECT unique_id, original_file_path, properties_yml_file_path
    FROM {{ info_schema('models') }}
    UNION ALL
    SELECT unique_id, original_file_path, properties_yml_file_path
    FROM {{ info_schema('macros') }}
    WHERE package_name = 'ztc_core'
      AND name NOT LIKE 'snapshot\_%' ESCAPE '\'
),

normalised AS (
    SELECT
        unique_id,
        original_file_path,
        properties_yml_file_path,
        REGEXP_REPLACE(original_file_path, '/[^/]+$', '') AS resource_dir,
        REGEXP_REPLACE(
            REGEXP_REPLACE(properties_yml_file_path, '^[a-z0-9_]+://', ''),
            '/[^/]+$', ''
        ) AS property_dir
    FROM resources
)

SELECT
    unique_id,
    original_file_path,
    properties_yml_file_path
FROM normalised
WHERE properties_yml_file_path IS NULL
   OR resource_dir != property_dir
