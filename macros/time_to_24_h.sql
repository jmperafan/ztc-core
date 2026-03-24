{% macro time_to_24_h(column) %}
case

when CONTAINS({{ column }}, 'am')
or (CONTAINS({{ column }}, 'pm') and left({{ column }}, 3) = '12:')
    then REGEXP_SUBSTR({{ column }}, '\\d{1,2}:\\d{2}:\\d{2}')

when CONTAINS({{ column }}, 'pm')
    then concat(
        cast(cast(REGEXP_SUBSTR({{ column }}, '^\\d{1,2}') as integer) + 12 as string),
        REGEXP_SUBSTR({{ column }}, ':\\d{2}:\\d{2}')
    )

end
{% endmacro %}
