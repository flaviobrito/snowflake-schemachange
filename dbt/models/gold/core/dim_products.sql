-- Product dimension with list margin.
select
    product_id,
    sku,
    product_name,
    category,
    brand,
    unit_price,
    unit_cost,
    {{ money('unit_price - unit_cost') }} as unit_margin,
    round(div0(unit_price - unit_cost, unit_price), 4)::number(10, 4) as unit_margin_pct,
    is_active
from {{ ref('stg_ecommerce__products') }}
