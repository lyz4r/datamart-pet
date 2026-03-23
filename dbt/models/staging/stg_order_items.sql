{{
    config(
        materialized='view',
        schema='staging'
    )
}}

select
    order_id,
    product_id,
    quantity,
    -- Проверяем, что количество положительное
    case when quantity <= 0 then 1 else quantity end as cleaned_quantity,
    current_timestamp as loaded_at
from {{ source('eshop', 'orders_products') }}