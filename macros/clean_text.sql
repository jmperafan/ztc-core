{% macro clean_text(column) %}
    regexp_replace(
        lower(
            trim({{ column }})
        ),
        '\s+',
        ' '
    )
{% endmacro %}