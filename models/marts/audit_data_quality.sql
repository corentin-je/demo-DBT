{{ config(materialized='table') }}

with data_quality as (
    select 'raw_customers' as table_name, COUNT(*) as row_count, 20 as expected_rows from {{ source('raw', 'raw_customers') }}
    UNION ALL
    select 'stg_customers', COUNT(*), 18 from {{ ref('stg_customers') }}  -- après dédup
    UNION ALL
    select 'fct_orders', COUNT(*), 25 from {{ ref('fct_orders') }}
    UNION ALL
    select 'dim_customers', COUNT(*), 18 from {{ ref('dim_customers') }}
)

select 
    table_name,
    row_count,
    expected_rows,
    CASE 
        WHEN row_count < expected_rows * 0.8 THEN 'ALERT_LOW'
        WHEN row_count > expected_rows * 1.2 THEN 'ALERT_HIGH'
        ELSE 'OK'
    END as quality_status,
    CURRENT_TIMESTAMP as audit_timestamp
from data_quality
