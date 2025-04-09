{{ config(materialized='view') }}

WITH final AS (
    SELECT id
        , name
        , cost
        , perishable
        , sku
    FROM {{ ref('jaffle_shop_raw__supplies') }}
)

SELECT * FROM final
