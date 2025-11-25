{{ config(materialized='view', tags=['staging']) }}

with source as (
    select * from {{ source('raw', 'raw_orders') }}
),

cleaned as (
    select 
        order_id,
        customer_id,
        TO_DATE(order_date, 'YYYY-MM-DD') as order_date,
        LOWER(status) as status,
        CAST(order_total AS NUMERIC) as total_amount
    from source
    where status IS NOT NULL AND order_total IS NOT NULL
)

select * from cleaned