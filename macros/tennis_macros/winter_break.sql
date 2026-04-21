{% macro is_winter_break(date_expr) %}
(
    -- Winter break in 2022
    {{ date_expr }} >= '2022-01-01'
    AND {{ date_expr }} <= '2022-03-19'
) OR (
    -- Winter break in 2023
    {{ date_expr }} >= '2022-12-06'
    AND {{ date_expr }} <= '2023-03-26'
)
{% endmacro %}
