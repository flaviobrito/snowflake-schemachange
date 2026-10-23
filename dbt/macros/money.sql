{#- Rounds monetary values to a fixed NUMBER(18, scale) across all models. -#}
{% macro money(expression, scale=2) -%}
    cast(round({{ expression }}, {{ scale }}) as number(18, {{ scale }}))
{%- endmacro %}
