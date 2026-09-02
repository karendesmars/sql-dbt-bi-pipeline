-- Payments are recorded per installment, at the order grain (not per order item).
-- We aggregate here so the fact table below can join one payment total per order
-- without duplicating rows for orders with multiple payment installments.

with order_payments as (
    select * from {{ ref('stg_olist__order_payments') }}
)

select
    order_id,
    sum(payment_value) as total_payment_value,
    count(*) as payment_installments_count,
    array_agg(distinct payment_type) as payment_types
from order_payments
group by order_id
