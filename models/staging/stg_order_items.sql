{{ config(materialized='view', tags=['staging']) }}

with source as (
    select * from {{ source('raw', 'raw_order_items') }}
),

cleaned as (
    select 
        order_item_id,
        order_id,
        product_id,
        CAST(quantity AS INTEGER) as quantity,
        CAST(unit_price AS NUMERIC) as unit_price,
        CAST(line_total AS NUMERIC) as line_total
    from source
)

select * from cleaned