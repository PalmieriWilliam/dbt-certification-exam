{{ config(materialized='view') }}

-- message to trigger CI
WITH final AS (
    SELECT id
        , customer
        , ordered_at
        , store_id
        , subtotal
        , {{ usd_to_brl('subtotal', 0) }} AS subtotal_brl
        , tax_paid
        , order_total
    FROM {{ ref('jaffle_shop_raw__orders') }}

    {{ limit_days(date_column = 'ordered_at', table = 'jaffle_shop_raw__orders', days = 10) }}

)

SELECT * FROM final