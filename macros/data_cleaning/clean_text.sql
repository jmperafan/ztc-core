{% macro clean_text(column) %}
    REGEXP_REPLACE(
        LOWER(
            TRIM({{ column }})
        ),
        '\s+',
        ' '
    )
{% endmacro %}
