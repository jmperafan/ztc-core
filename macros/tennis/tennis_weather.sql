{% macro tennis_weather(temperature, precipitation, wind_speed) %}
    {{temperature}} BETWEEN 5 AND 35
    AND {{precipitation}} = 5
    AND {{wind_speed}} <= 20
{% endmacro %}
