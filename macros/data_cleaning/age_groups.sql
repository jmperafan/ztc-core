{% macro age_group(age) %}
    FLOOR({{ age }} / 10) * 10
{% endmacro %}
