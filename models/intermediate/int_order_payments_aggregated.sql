-- Payments are recorded one row per payment method used on an order (payment_sequential),
-- not one row per installment: a single row's payment_installments says how many
-- installments that specific payment was split into, it does not add more rows.
-- We aggregate here so the fact table below can join one payment total per order
-- without duplicating rows for orders paid with more than one method.

with order_payments as (
    select * from {{ ref('stg_olist__order_payments') }}
)

select
    order_id,
    sum(payment_value) as total_payment_value,
    count(*) as payment_records_count,
    array_agg(distinct payment_type) as payment_types
from order_payments
group by order_id
