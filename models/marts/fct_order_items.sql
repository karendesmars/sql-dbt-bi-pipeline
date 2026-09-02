-- Grain: one row per order item (order_id, order_item_id).
-- Payment totals are at the order grain (see int_order_payments_aggregated), so
-- total_payment_value repeats across items of the same order by design: it is not
-- meant to be summed across items without deduplicating on order_id first.

with order_items as (
    select * from {{ ref('stg_olist__order_items') }}
),

orders as (
    select * from {{ ref('stg_olist__orders') }}
),

payments as (
    select * from {{ ref('int_order_payments_aggregated') }}
)

select
    order_items.order_id,
    order_items.order_item_id,
    order_items.product_id,
    order_items.seller_id,
    orders.customer_id,
    orders.order_status,
    orders.order_purchase_at,
    orders.order_delivered_customer_at,
    orders.order_estimated_delivery_at,
    datediff('day', orders.order_purchase_at, orders.order_delivered_customer_at) as delivery_days,
    datediff(
        'day', orders.order_estimated_delivery_at, orders.order_delivered_customer_at
    ) as delivery_delay_days,
    order_items.price,
    order_items.freight_value,
    payments.total_payment_value,
    payments.payment_installments_count
from order_items
left join orders
    on order_items.order_id = orders.order_id
left join payments
    on order_items.order_id = payments.order_id
