{{
    config(
        materialized='table',
        schema='marts',
        unique_key='sales_id',
        sort='order_date',
        dist='customer_id'
    )
}}

with orders as (
    select * from {{ ref('stg_orders') }}
),
order_items as (
    select * from {{ ref('stg_order_items')}}
),
products as (
    select * from {{ ref('stg_products')}}
),
order_aggregates as (
    select * from {{ ref('int_order_aggregates')}}
)

select
    -- Создаем уникальный ключ
    {{ dbt_utils.generate_surrogate_key(['o.order_id', 'p.product_id']) }} as sales_id,
    o.order_id,
    o.customer_id,
    o.order_timestamp,
    o.order_date,
    o.order_hour,
    o.order_day_of_week,
    o.season,
    o.delivery_city,
    p.product_id,
    p.product_name,
    p.category,
    p.price_category,
    oi.cleaned_quantity as quantity,
    p.price as unit_price,
    (oi.cleaned_quantity * p.price) as revenue,
    oa.order_total,
    oa.unique_products_count,
    oa.total_items_count,
    -- Добавляем метаданные
    current_timestamp as updated_at
from orders o
inner join order_items oi on o.order_id = oi.order_id
inner join products p on oi.product_id = p.product_id
inner join order_aggregates oa on o.order_id = oa.order_id