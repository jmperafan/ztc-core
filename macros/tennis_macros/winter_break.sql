{% macro is_winter_break(date_expr) %}
{% set breaks = var('winter_breaks', []) %}
(
    {% if breaks %}
{% for break in breaks %}
            ({{ date_expr }} >= '{{ break[0] }}' AND {{ date_expr }} <= '{{ break[1] }}')
            {% if not loop.last %} OR {% endif %}
        {% endfor %}
    {% else %}
        FALSE
    {% endif %}
)
{% endmacro %}
