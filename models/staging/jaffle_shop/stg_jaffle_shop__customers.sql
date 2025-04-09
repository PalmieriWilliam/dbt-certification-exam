{{ config(materialized='view') }}

WITH final AS (
    SELECT id
        , name
    FROM {{ ref('jaffle_shop_raw__customers') }}
)

SELECT * FROM final