-- Tier 1 — staging is a 1:1 rename layer, not a join layer.
--
-- A staging model that reads two sources has started modelling. That work
-- belongs in intermediate, where the join is visible to anyone reading the
-- DAG rather than buried in a model named stg_*.
--
-- selection_filter_on is set in _checks.yml because this query returns
-- child_unique_id rather than a bare unique_id column.
SELECT
    e.child_unique_id,
    COUNT(*) AS source_parents
FROM {{ info_schema('edges') }} AS e
INNER JOIN {{ info_schema('models') }} AS m
    ON m.unique_id = e.child_unique_id
WHERE e.parent_unique_id LIKE 'source.%'
  AND m.original_file_path LIKE 'models/staging/%'
GROUP BY e.child_unique_id
HAVING COUNT(*) > 1
