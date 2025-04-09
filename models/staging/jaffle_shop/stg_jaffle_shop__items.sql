{{ config(materialized='view') }}

WITH final AS (
    SELECT id
        , order_id
        , sku
    FROM {{ ref('jaffle_shop_raw__items') }}
)

SELECT * FROM final