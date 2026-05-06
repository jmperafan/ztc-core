{% macro dutch_bool(column) %}
    CASE LOWER({{ column }})
        WHEN 'ja' THEN TRUE
        WHEN 'nee' THEN FALSE
        WHEN 'true' THEN TRUE
        WHEN 'false' THEN FALSE
        WHEN '1' THEN TRUE
        WHEN '0' THEN FALSE
    END
{% endmacro %}
