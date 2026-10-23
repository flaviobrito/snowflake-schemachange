{#- Fails for non-null values that do not look like an email address. -#}
{% test is_valid_email(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
    and not regexp_like(
        lower(trim({{ column_name }})), '^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$'
    )

{% endtest %}
