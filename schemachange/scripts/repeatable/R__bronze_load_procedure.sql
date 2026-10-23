{% import "modules/bronze.sql" as bronze %}
-- Repeatable script: re-applied by schemachange whenever its rendered content changes.
-- Loads every file in the landing stage into the matching BRONZE table.
-- COPY INTO keeps load metadata, so already loaded files are skipped (idempotent).
CREATE OR REPLACE PROCEDURE {{ database }}.BRONZE.LOAD_FROM_STAGE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
COMMENT = 'Loads staged CSV files into BRONZE landing tables.'
AS
$$
BEGIN
    {{ bronze.copy_into(database, 'CUSTOMERS', [
        'customer_id', 'first_name', 'last_name', 'email', 'phone', 'country_code',
        'state', 'city', 'created_at', 'updated_at', 'marketing_opt_in'
    ], 'customers') }};

    {{ bronze.copy_into(database, 'PRODUCTS', [
        'product_id', 'sku', 'product_name', 'category', 'brand', 'unit_price',
        'unit_cost', 'is_active', 'created_at', 'updated_at'
    ], 'products') }};

    {{ bronze.copy_into(database, 'ORDERS', [
        'order_id', 'customer_id', 'order_status', 'order_channel', 'currency_code',
        'shipping_amount', 'discount_amount', 'ordered_at', 'updated_at'
    ], 'orders') }};

    {{ bronze.copy_into(database, 'ORDER_ITEMS', [
        'order_item_id', 'order_id', 'product_id', 'quantity', 'unit_price'
    ], 'order_items') }};

    {{ bronze.copy_into(database, 'PAYMENTS', [
        'payment_id', 'order_id', 'payment_method', 'payment_status', 'amount', 'paid_at'
    ], 'payments') }};

    RETURN 'BRONZE load completed';
END;
$$;
