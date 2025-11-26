{{ config(materialized='table') }}

with customers as (
    select * from {{ ref('int_customers') }}
),

customer_metrics as (
    select * from {{ ref('int_customer_lifetime') }}
),

final as (
    select 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.signup_date,
        COALESCE(cm.total_orders, 0) as total_orders,
        COALESCE(cm.completed_orders, 0) as completed_orders,
        COALESCE(cm.total_spent, 0) as customer_lifetime_value,
        ROUND(COALESCE(cm.avg_order_value, 0), 2) as avg_order_value,
        cm.first_order_date,
        cm.last_order_date,
        CASE 
            WHEN cm.total_orders IS NULL THEN 'never_ordered'
            WHEN cm.total_orders >= 5 THEN 'vip'
            WHEN cm.total_orders >= 3 THEN 'loyal'
            WHEN cm.total_orders >= 1 THEN 'regular'
            ELSE 'other'
        END as customer_segment,
        CASE 
            WHEN cm.last_order_date >= CURRENT_DATE - INTERVAL '90 days' THEN true
            ELSE false
        END as is_active_customer
    from customers c
    left join customer_metrics cm on c.customer_id = cm.customer_id
)

select * from final