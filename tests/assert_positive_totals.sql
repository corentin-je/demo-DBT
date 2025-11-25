SELECT order_id, total_amount
FROM {{ ref('fct_orders') }}
WHERE total_amount < 0