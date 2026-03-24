{{
    config(
        materialized='view',
        schema='staging'
    )
}}

select
    id as product_id,
    name as product_name,
    category,
    price,
    description,
    -- Добавляем категории цен
    case 
        when price < 1000 then 'Budget'
        when price between 1000 and 5000 then 'Standard'
        when price between 5001 and 20000 then 'Premium'
        else 'Luxury'
    end as price_category,
    current_timestamp as loaded_at
from {{ source('eshop', 'products') }}
where price > 0  -- исключаем товары с нулевой ценой