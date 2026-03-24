{{
    config(
        materialized='view',
        schema='staging'
    )
}}

select
    id as order_id,
    user_id as customer_id,
    order_timestamp,
    date(order_timestamp) as order_date,
    extract(hour from order_timestamp) as order_hour,
    extract(dow from order_timestamp) as order_day_of_week,
    delivery_city,
    -- Определяем сезон
    case 
        when extract(month from order_timestamp) in (12, 1, 2) then 'Winter'
        when extract(month from order_timestamp) in (3, 4, 5) then 'Spring'
        when extract(month from order_timestamp) in (6, 7, 8) then 'Summer'
        else 'Autumn'
    end as season,
    current_timestamp as loaded_at
from {{ source('eshop', 'orders') }}