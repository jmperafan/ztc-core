-- Migrated from dbt-bouncer: check_model_has_tests_by_type,
-- check_model_test_coverage (100%), check_model_has_tests_by_name,
-- check_model_has_unique_test.
--
-- Two tiers. Every model needs at least one test. Core models additionally
-- need both a not_null and a uniqueness test, where uniqueness may be a plain
-- `unique` or a compound test — the composite-grain facts use
-- unique_combination_of_columns instead, and that counts.
WITH test_counts AS (
    SELECT
        m.unique_id,
        m.original_file_path,
        COUNT(t.unique_id) AS n_tests,
        SUM(CASE WHEN t.test_name = 'not_null' THEN 1 ELSE 0 END) AS n_not_null,
        SUM(CASE WHEN t.test_name IN ('unique', 'unique_combination_of_columns')
                 THEN 1 ELSE 0 END) AS n_unique
    FROM {{ info_schema('models') }} AS m
    LEFT JOIN {{ info_schema('data_tests') }} AS t
        ON t.node_unique_id = m.unique_id
    GROUP BY m.unique_id, m.original_file_path
)

SELECT
    unique_id,
    n_tests,
    n_not_null,
    n_unique,
    CASE
        WHEN n_tests = 0 THEN 'model has no tests at all'
        WHEN original_file_path LIKE 'models/core/%' AND n_not_null = 0
            THEN 'core model has no not_null test'
        WHEN original_file_path LIKE 'models/core/%' AND n_unique = 0
            THEN 'core model has no uniqueness test'
    END AS rule_broken
FROM test_counts
WHERE n_tests = 0
   OR (original_file_path LIKE 'models/core/%' AND (n_not_null = 0 OR n_unique = 0))
