{% macro is_winter_break(date) %}
(
    -- Winter break in 2022
    {{ date }} >= '2022-01-01'
    AND {{ date }} <= '2022-03-19'
) OR (
    -- Winter break in 2023
    {{ date }} >= '2022-12-06'
    AND {{ date }} <= '2023-03-26'
)
{% endmacro %}
