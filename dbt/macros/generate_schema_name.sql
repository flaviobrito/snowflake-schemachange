{#-
  Environments are isolated by database (ECOMMERCE_DEV, ECOMMERCE_PROD,
  ECOMMERCE_PR_<n>), so custom schemas are used verbatim instead of being
  prefixed with the target schema: SILVER, GOLD and AUDIT exist in every database.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema | upper }}
    {%- else -%}
        {{ custom_schema_name | trim | upper }}
    {%- endif -%}
{%- endmacro %}
