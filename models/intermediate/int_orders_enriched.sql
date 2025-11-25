{{ config(materialized='view') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

payments as (
    select * from {{ ref('stg_payments') }}
),

order_items_agg as (
    select 
        order_id,
        COUNT(*) as item_count,
        SUM(line_total) as items_total
    from order_items
    group by order_id
),

payments_agg as (
    select 
        order_id,
        SUM(amount) as payment_total,
        COUNT(*) as payment_count
    from payments
    where status = 'success'
    group by order_id
),

final as (
    select 
        o.order_id,
        o.customer_id,
        o.order_date,
        o.status as order_status,
        o.total_amount,
        c.first_name,
        c.last_name,
        c.email,
        oi.item_count,
        oi.items_total,
        COALESCE(p.payment_total, 0) as payment_total,
        COALESCE(p.payment_count, 0) as payment_count
    from orders o
    left join customers c on o.customer_id = c.customer_id
    left join order_items_agg oi on o.order_id = oi.order_id
    left join payments_agg p on o.order_id = p.order_id
)

select * from final