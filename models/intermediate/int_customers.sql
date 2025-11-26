-- models/intermediate/int_customers.sql
/*
    Intermediate customers table.
    
    This is a pass-through from stg_customers.
    It serves as a central hub for customer enrichments
    and calculations before joining to marts.
    
    Future: Add customer segments, RFM scores, etc.
*/

SELECT 
    *
FROM {{ ref('stg_customers') }}