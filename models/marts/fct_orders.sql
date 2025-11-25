{{ config(materialized='table') }}

with orders_enriched as (
    select * from {{ ref('int_orders_enriched') }}
),

final as (
    select 
        {{ dbt_utils.generate_surrogate_key(['order_id', 'customer_id', 'order_date']) }} as order_key,
        order_id,
        customer_id,
        order_date,
        first_name,
        last_name,
        email,
        order_status,
        total_amount,
        payment_total,
        payment_count,
        item_count,
        (total_amount - payment_total) as payment_diff,
        CASE 
            WHEN order_status = 'completed' AND (total_amount - payment_total) = 0 THEN 'paid_completed'
            WHEN order_status = 'completed' AND (total_amount - payment_total) > 0 THEN 'unpaid_completed'
            WHEN order_status = 'pending' THEN 'pending'
            WHEN order_status = 'cancelled' THEN 'cancelled'
            ELSE 'other'
        END as order_category
    from orders_enriched
)

select * from final