{{ config(materialized='view', tags=['staging']) }}

with source as (
    select * from {{ source('raw', 'raw_payments') }}
),

cleaned as (
    select 
        payment_id,
        order_id,
        LOWER(payment_method) as payment_method,
        CAST(amount AS NUMERIC) as amount,
        CASE 
            WHEN payment_date LIKE '____-__-__' THEN TO_DATE(payment_date, 'YYYY-MM-DD')
            WHEN payment_date LIKE '__/__/____' THEN TO_DATE(payment_date, 'DD/MM/YYYY')
            WHEN payment_date LIKE '__-__-____' THEN TO_DATE(payment_date, 'DD-MM-YYYY')
            WHEN payment_date LIKE '____/__/__' THEN TO_DATE(payment_date, 'YYYY/MM/DD')
            ELSE NULL
        END as payment_date,
        LOWER(status) as status
    from source
    where amount IS NOT NULL
)

select * from cleaned