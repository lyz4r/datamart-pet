{{
    config(
        materialized='table',
        schema='marts'
    )
}}

with sales as (
    select * from {{ ref('fct_sales') }}
)

select
    category,
    count(distinct order_id) as total_orders,
    sum(revenue) as total_revenue,
    sum(quantity) as total_items_sold,
    avg(revenue) as avg_revenue_per_order,
    count(distinct product_id) as unique_products,
    sum(revenue) / nullif(sum(quantity), 0) as avg_price_per_item
from sales
group by category
order by total_revenue desc