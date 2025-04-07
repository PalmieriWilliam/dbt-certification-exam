{{ config(materialized='view') }}

WITH final AS (
    SELECT id
        , name
        , opened_at
        , tax_rate
    FROM {{ ref('jaffle_shop_raw__stores') }}
)

SELECT * FROM final