{{ config(materialized='view') }}

WITH final AS (
    SELECT id
        , customer
        , ordered_at
        , store_id
        , subtotal
        , tax_paid
        , order_total
    FROM {{ ref('jaffle_shop_raw__orders') }}
)

SELECT * FROM final