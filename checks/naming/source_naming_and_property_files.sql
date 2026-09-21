-- Migrated from dbt-bouncer: check_source_names, check_source_file_name,
-- check_source_property_file_location.
--
-- Sources are declared in YAML only, so name and file are both properties of
-- the property file rather than of a .sql file.
SELECT DISTINCT
    unique_id,
    source_name,
    CASE
        WHEN NOT REGEXP_MATCHES(source_name, '^[a-z][a-z0-9_]*$')
            THEN 'source name must be lower_snake_case'
        WHEN NOT REGEXP_MATCHES(
                REGEXP_EXTRACT(original_file_path, '[^/]+$'),
                '^_[a-z][a-z0-9_]*\.yml$')
            THEN 'source property file must be named _<name>.yml'
        WHEN original_file_path NOT LIKE 'models/staging/%'
            THEN 'source property file must live in models/staging'
        ELSE NULL
    END AS rule_broken
FROM {{ info_schema('sources') }}
WHERE CASE
        WHEN NOT REGEXP_MATCHES(source_name, '^[a-z][a-z0-9_]*$') THEN 1
        WHEN NOT REGEXP_MATCHES(
                REGEXP_EXTRACT(original_file_path, '[^/]+$'),
                '^_[a-z][a-z0-9_]*\.yml$') THEN 1
        WHEN original_file_path NOT LIKE 'models/staging/%' THEN 1
        ELSE 0
      END = 1
