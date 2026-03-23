{{
    config(
        materialized='ephemeral'
    )
}}

with order_items as (
    select * from {{ ref('stg_order_items') }}
),
products as (
    select * from {{ ref('stg_products') }}
)

select
    oi.order_id,
    sum(oi.cleaned_quantity * p.price) as order_total,
    count(distinct oi.product_id) as unique_products_count,
    sum(oi.cleaned_quantity) as total_items_count,
    avg(p.price) as avg_product_price
from order_items oi
left join products p on oi.product_id = p.product_id
group by oi.order_id