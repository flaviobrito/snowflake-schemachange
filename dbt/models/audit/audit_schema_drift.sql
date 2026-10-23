-- Compares the physical BRONZE schema with the columns declared in dbt sources.
-- Any status other than 'aligned' is drift: a migration without a matching
-- source declaration, a manual change in Snowflake, or a stale YAML entry.
{{ config(materialized='view') }}

with physical as (

    select
        table_schema,
        table_name,
        column_name,
        data_type as physical_data_type
    from {{ target.database }}.information_schema.columns
    where table_schema = '{{ var("drift_monitored_schema") | upper }}'

),

declared as (

    {{ declared_source_columns(var("drift_monitored_schema")) }}

),

declared_normalized as (

    select
        table_schema,
        table_name,
        column_name,
        -- Snowflake reports VARCHAR/STRING as TEXT and drops precision.
        case
            when split_part(declared_data_type, '(', 1) in ('VARCHAR', 'STRING', 'CHAR')
                then 'TEXT'
            else split_part(declared_data_type, '(', 1)
        end as declared_data_type
    from declared
    where table_name is not null

)

select
    coalesce(physical.table_schema, declared_normalized.table_schema) as table_schema,
    coalesce(physical.table_name, declared_normalized.table_name) as table_name,
    coalesce(physical.column_name, declared_normalized.column_name) as column_name,
    physical.physical_data_type,
    declared_normalized.declared_data_type,
    case
        when physical.column_name is null then 'missing_in_database'
        when declared_normalized.column_name is null then 'undeclared_in_dbt'
        when declared_normalized.declared_data_type is not null
            and declared_normalized.declared_data_type != physical.physical_data_type
            then 'type_mismatch'
        else 'aligned'
    end as drift_status,
    current_timestamp() as checked_at
from physical
full outer join declared_normalized
    on physical.table_schema = declared_normalized.table_schema
        and physical.table_name = declared_normalized.table_name
        and physical.column_name = declared_normalized.column_name
