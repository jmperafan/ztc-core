{% test is_between(model, column_name, min_value, max_value) %}

WITH validation AS (
    SELECT {{ column_name }} AS value_under_test
    FROM {{ model }}
    WHERE {{ column_name }} IS NOT NULL
)

SELECT value_under_test
FROM validation
WHERE value_under_test < {{ min_value }}
   OR value_under_test > {{ max_value }}

{% endtest %}
