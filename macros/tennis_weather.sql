{% macro tennis_weather(temperature, precipitation, wind_speed) %}
    temperature between 10 and 35
    and precipitation = 0
    and wind_speed <= 20
{% endmacro %}
