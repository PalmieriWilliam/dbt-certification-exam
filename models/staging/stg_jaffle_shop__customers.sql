{{ config(materialized='view') }}

SELECT id
    , name
FROM {{ ref('jaffle_shop_raw__customers') }}
