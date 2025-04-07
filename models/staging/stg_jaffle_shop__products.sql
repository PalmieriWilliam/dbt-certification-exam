{{ config(materialized='view') }}

WITH final AS (
    SELECT sku
        , name
        , type
        , price
        , description
    FROM {{ ref('jaffle_shop_raw__products') }}
)

SELECT * FROM final