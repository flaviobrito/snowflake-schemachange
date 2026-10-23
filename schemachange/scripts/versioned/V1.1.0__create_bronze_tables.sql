{% import "modules/bronze.sql" as bronze %}
-- Raw landing tables mirroring the e-commerce operational system exports.
-- Columns stay close to the source contract; typing and cleaning happen in SILVER.
USE SCHEMA {{ database }}.BRONZE;

CREATE TABLE IF NOT EXISTS CUSTOMERS (
    customer_id     VARCHAR       NOT NULL COMMENT 'Natural key from the storefront',
    first_name      VARCHAR,
    last_name       VARCHAR,
    email           VARCHAR,
    phone           VARCHAR,
    country_code    VARCHAR(2)    COMMENT 'ISO 3166-1 alpha-2',
    state           VARCHAR,
    city            VARCHAR,
    created_at      TIMESTAMP_NTZ,
    updated_at      TIMESTAMP_NTZ,
    {{ bronze.metadata_columns() }}
)
COMMENT = 'Storefront customer accounts.';

CREATE TABLE IF NOT EXISTS PRODUCTS (
    product_id      VARCHAR       NOT NULL,
    sku             VARCHAR,
    product_name    VARCHAR,
    category        VARCHAR,
    brand           VARCHAR,
    unit_price      NUMBER(12, 2),
    unit_cost       NUMBER(12, 2),
    is_active       BOOLEAN,
    created_at      TIMESTAMP_NTZ,
    updated_at      TIMESTAMP_NTZ,
    {{ bronze.metadata_columns() }}
)
COMMENT = 'Product catalog.';

CREATE TABLE IF NOT EXISTS ORDERS (
    order_id          VARCHAR     NOT NULL,
    customer_id       VARCHAR,
    order_status      VARCHAR     COMMENT 'placed | paid | shipped | delivered | cancelled | returned',
    order_channel     VARCHAR     COMMENT 'web | mobile_app | marketplace',
    currency_code     VARCHAR(3),
    shipping_amount   NUMBER(12, 2),
    discount_amount   NUMBER(12, 2),
    ordered_at        TIMESTAMP_NTZ,
    updated_at        TIMESTAMP_NTZ,
    {{ bronze.metadata_columns() }}
)
COMMENT = 'Order headers.';

CREATE TABLE IF NOT EXISTS ORDER_ITEMS (
    order_item_id   VARCHAR       NOT NULL,
    order_id        VARCHAR,
    product_id      VARCHAR,
    quantity        NUMBER(10, 0),
    unit_price      NUMBER(12, 2) COMMENT 'Price charged at order time',
    {{ bronze.metadata_columns() }}
)
COMMENT = 'Order line items.';

CREATE TABLE IF NOT EXISTS PAYMENTS (
    payment_id      VARCHAR       NOT NULL,
    order_id        VARCHAR,
    payment_method  VARCHAR       COMMENT 'credit_card | debit_card | pix | boleto | paypal',
    payment_status  VARCHAR       COMMENT 'approved | declined | refunded',
    amount          NUMBER(12, 2),
    paid_at         TIMESTAMP_NTZ,
    {{ bronze.metadata_columns() }}
)
COMMENT = 'Payment transactions.';
