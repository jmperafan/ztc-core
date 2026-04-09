{% macro time_to_24_h(column) %}
CASE

WHEN CONTAINS({{ column }}, 'am')
OR (CONTAINS({{ column }}, 'pm') AND LEFT({{ column }}, 3) = '12:')
    THEN REGEXP_SUBSTR({{ column }}, '\\d{1,2}:\\d{2}:\\d{2}')

WHEN CONTAINS({{ column }}, 'pm')
    THEN CONCAT(
        CAST(CAST(REGEXP_SUBSTR({{ column }}, '^\\d{1,2}') AS INTEGER) + 12 AS STRING),
        REGEXP_SUBSTR({{ column }}, ':\\d{2}:\\d{2}')
    )

END
{% endmacro %}
