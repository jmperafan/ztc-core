-- Migrated from dbt-bouncer: check_model_directories.
--
-- Only the three canonical layers may exist under models/. A new top-level
-- folder is a structural decision, not something that lands in a PR by
-- accident. Property-only YAML at the models/ root (_groups.yml,
-- _exposures.yml) is not a model and never reaches this view.
SELECT
    unique_id,
    original_file_path,
    SPLIT_PART(original_file_path, '/', 2) AS offending_directory
FROM {{ info_schema('models') }}
WHERE SPLIT_PART(original_file_path, '/', 2)
      NOT IN ('staging', 'intermediate', 'core')
