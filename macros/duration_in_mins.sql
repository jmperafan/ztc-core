{% macro duration_in_mins(start_time, end_time) %}
    DATEDIFF('minute', {{ start_time }}, {{ end_time }})
{% endmacro %}
