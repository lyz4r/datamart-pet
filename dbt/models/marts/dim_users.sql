{{
    config(
        materialized='table',
        schema='marts',
        unique_key='user_id'
    )
}}

with users as (
    select * from {{ ref('stg_users') }}
),
user_metrics as (
    select * from {{ ref('int_user_metrics') }}
)

select
    u.user_id,
    u.first_name,
    u.last_name,
    u.full_name,
    u.email,
    u.birthdate,
    u.age,
    u.age_group,
    coalesce(um.total_orders, 0) as total_orders,
    coalesce(um.total_spent, 0) as total_spent,
    coalesce(um.avg_order_value, 0) as avg_order_value,
    um.first_order_date,
    um.last_order_date,
    -- Сегментация пользователей по активности
    case 
        when um.total_spent is null then 'No purchases'
        when um.total_spent >= 50000 then 'VIP'
        when um.total_spent >= 10000 then 'Regular'
        when um.total_spent >= 1000 then 'Occasional'
        else 'New'
    end as customer_segment,
    u.loaded_at
from users u
left join user_metrics um on u.user_id = um.customer_id