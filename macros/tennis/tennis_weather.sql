{% macro tennis_weather(temperature, precipitation, wind_speed) %}
    temperature BETWEEN 10 AND 35
    AND precipitation = 0
    AND wind_speed <= 20
{% endmacro %}
