{{ config(materialized='view') }}

with orders_enriched as (
    select * from {{ ref('int_orders_enriched') }}
),

customer_metrics as (
    select 
        customer_id,
        COUNT(*) as total_orders,
        COUNT(CASE WHEN order_status = 'completed' THEN 1 END) as completed_orders,
        SUM(total_amount) as total_spent,
        AVG(total_amount) as avg_order_value,
        MAX(total_amount) as max_order_value,
        MIN(order_date) as first_order_date,
        MAX(order_date) as last_order_date,
        SUM(payment_total) as total_paid
    from orders_enriched
    group by customer_id
)

select * from customer_metrics