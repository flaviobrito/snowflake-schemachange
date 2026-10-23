-- Medallion layers. BRONZE is owned by schemachange (raw landing tables);
-- SILVER, GOLD and AUDIT are populated by dbt.
USE DATABASE {{ database }};

CREATE SCHEMA IF NOT EXISTS BRONZE
    COMMENT = 'Raw landing layer: source-shaped data, loaded as-is with lineage metadata.';

CREATE SCHEMA IF NOT EXISTS SILVER
    COMMENT = 'Cleaned, typed and deduplicated entities built by dbt.';

CREATE SCHEMA IF NOT EXISTS GOLD
    COMMENT = 'Business-ready dimensional models and aggregates built by dbt.';

CREATE SCHEMA IF NOT EXISTS AUDIT
    COMMENT = 'Data quality results, schema drift monitoring and deployment logs.';
