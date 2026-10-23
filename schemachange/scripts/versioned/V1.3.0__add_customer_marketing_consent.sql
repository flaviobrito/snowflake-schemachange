-- Schema evolution example: the storefront started exporting marketing consent.
-- The matching column is declared in dbt/models/silver/ecommerce/_ecommerce__sources.yml;
-- removing it from either side is reported by the schema drift audit.
ALTER TABLE {{ database }}.BRONZE.CUSTOMERS
    ADD COLUMN IF NOT EXISTS marketing_opt_in BOOLEAN
    COMMENT 'Customer accepted marketing communication';
