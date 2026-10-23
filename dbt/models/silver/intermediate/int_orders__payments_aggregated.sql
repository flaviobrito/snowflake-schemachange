-- Order-level rollup of payment transactions.
with payments as (

    select * from {{ ref('stg_ecommerce__payments') }}

)

select
    order_id,
    count(*) as payment_attempt_count,
    sum(iff(payment_status = 'approved', amount, 0)) as approved_amount,
    sum(iff(payment_status = 'refunded', amount, 0)) as refunded_amount,
    max_by(payment_method, paid_at) as last_payment_method,
    max(iff(payment_status = 'approved', paid_at, null)) as last_approved_at
from payments
group by order_id
