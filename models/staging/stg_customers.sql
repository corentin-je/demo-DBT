with source as (
    select * from {{ source('raw', 'raw_customers') }}
),

deduplicated as (
    select 
        customer_id,
        first_name,
        last_name,
        LOWER(COALESCE(email, 'unknown')) as email,
        CASE 
            WHEN signup_date LIKE '____-__-__' THEN TO_DATE(signup_date, 'YYYY-MM-DD')
            WHEN signup_date LIKE '__/__/____' THEN TO_DATE(signup_date, 'DD/MM/YYYY')
            WHEN signup_date LIKE '__-__-____' THEN TO_DATE(signup_date, 'DD-MM-YYYY')
            WHEN signup_date LIKE '____/__/__' THEN TO_DATE(signup_date, 'YYYY/MM/DD')
            ELSE NULL
        END as signup_date,
        ROW_NUMBER() OVER (PARTITION BY LOWER(email), first_name, last_name ORDER BY customer_id) as row_num
    from source
),

cleaned as (
    select * from deduplicated
    where row_num = 1
)

select * from cleaned