-- =============================================================================
-- One-time account bootstrap.
--
-- Run manually by an administrator (SECURITYADMIN / SYSADMIN / ACCOUNTADMIN)
-- before the first pipeline execution. Everything after this point is owned
-- and evolved by schemachange (database objects) and dbt (transformations).
--
-- Replace <RSA_PUBLIC_KEY> with the public key generated as described in
-- docs/runbook.md (single line, without the BEGIN/END header lines).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Functional roles
-- -----------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS ECOMMERCE_DEPLOYER
    COMMENT = 'Owns e-commerce databases; runs schemachange migrations and environment clones.';
CREATE ROLE IF NOT EXISTS ECOMMERCE_TRANSFORMER
    COMMENT = 'Runs dbt: reads BRONZE, builds SILVER, GOLD and AUDIT.';
CREATE ROLE IF NOT EXISTS ECOMMERCE_READER
    COMMENT = 'Read-only access to GOLD for BI tools and analysts.';

-- Role hierarchy: deployer can do everything the transformer can.
GRANT ROLE ECOMMERCE_READER TO ROLE ECOMMERCE_TRANSFORMER;
GRANT ROLE ECOMMERCE_TRANSFORMER TO ROLE ECOMMERCE_DEPLOYER;
GRANT ROLE ECOMMERCE_DEPLOYER TO ROLE SYSADMIN;

-- -----------------------------------------------------------------------------
-- 2. Compute and cost guardrails
-- -----------------------------------------------------------------------------
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS ECOMMERCE_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Shared warehouse for e-commerce migrations, loads and dbt runs.';

GRANT USAGE, OPERATE ON WAREHOUSE ECOMMERCE_WH TO ROLE ECOMMERCE_TRANSFORMER;
GRANT USAGE ON WAREHOUSE ECOMMERCE_WH TO ROLE ECOMMERCE_READER;

USE ROLE ACCOUNTADMIN;

CREATE RESOURCE MONITOR IF NOT EXISTS ECOMMERCE_MONTHLY_MONITOR
    WITH CREDIT_QUOTA = 20
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 80 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND
        ON 110 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE ECOMMERCE_WH SET RESOURCE_MONITOR = ECOMMERCE_MONTHLY_MONITOR;

-- -----------------------------------------------------------------------------
-- 3. Account-level privileges
-- -----------------------------------------------------------------------------
-- CREATE DATABASE: needed for zero-copy clones (pull request environments
-- and pre-deployment backups).
GRANT CREATE DATABASE ON ACCOUNT TO ROLE ECOMMERCE_DEPLOYER;

-- Data Metric Functions (Enterprise edition or higher). Skip on Standard
-- edition and set enable_data_metric_functions: false in schemachange vars.
GRANT EXECUTE DATA METRIC FUNCTION ON ACCOUNT TO ROLE ECOMMERCE_DEPLOYER;
GRANT DATABASE ROLE SNOWFLAKE.DATA_METRIC_USER TO ROLE ECOMMERCE_DEPLOYER;
GRANT APPLICATION ROLE SNOWFLAKE.DATA_QUALITY_MONITORING_VIEWER TO ROLE ECOMMERCE_DEPLOYER;

-- -----------------------------------------------------------------------------
-- 4. Environment databases (objects inside are managed by schemachange)
-- -----------------------------------------------------------------------------
USE ROLE ECOMMERCE_DEPLOYER;

CREATE DATABASE IF NOT EXISTS ECOMMERCE_DEV
    DATA_RETENTION_TIME_IN_DAYS = 1
    COMMENT = 'E-commerce lakehouse - development environment.';

CREATE DATABASE IF NOT EXISTS ECOMMERCE_PROD
    DATA_RETENTION_TIME_IN_DAYS = 7
    COMMENT = 'E-commerce lakehouse - production environment.';

-- -----------------------------------------------------------------------------
-- 5. Service user for CI/CD (key-pair authentication, no password)
-- -----------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

CREATE USER IF NOT EXISTS SVC_ECOMMERCE_CICD
    TYPE = SERVICE
    DEFAULT_ROLE = ECOMMERCE_DEPLOYER
    DEFAULT_WAREHOUSE = ECOMMERCE_WH
    RSA_PUBLIC_KEY = '<RSA_PUBLIC_KEY>'
    COMMENT = 'GitHub Actions service user for schemachange and dbt.';

GRANT ROLE ECOMMERCE_DEPLOYER TO USER SVC_ECOMMERCE_CICD;
-- Granted directly too, so dbt sessions can run with the least-privileged role.
GRANT ROLE ECOMMERCE_TRANSFORMER TO USER SVC_ECOMMERCE_CICD;
