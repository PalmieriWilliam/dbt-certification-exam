{{ config(materialized='view') }}

SELECT id
    , order_id
    , sku
FROM {{ ref('jaffle_shop_raw__items') }}
