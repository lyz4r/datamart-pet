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
    order_date,
    count(distinct order_id) as total_orders,
    count(distinct customer_id) as unique_customers,
    sum(revenue) as total_revenue,
    sum(quantity) as total_items_sold,
    avg(revenue) as avg_revenue_per_order,
    avg(quantity) as avg_items_per_order,
    sum(revenue) / nullif(count(distinct customer_id), 0) as revenue_per_customer
from sales
group by order_date
order by order_date desc