{{ config(materialized='view', tags=['staging']) }}

with source as (
    select * from {{ source('raw', 'raw_products') }}
),

cleaned as (
    select 
        product_id,
        product_name,
        category,
        CAST(price AS NUMERIC) as price,
        COALESCE(CAST(stock_quantity AS INTEGER), 0) as stock_quantity,
        CASE 
            WHEN created_date LIKE '____-__-__' THEN TO_DATE(created_date, 'YYYY-MM-DD')
            WHEN created_date LIKE '__/__/____' THEN TO_DATE(created_date, 'DD/MM/YYYY')
            ELSE NULL
        END as created_date
    from source
    where price IS NOT NULL
)

select * from cleaned