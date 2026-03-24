{{
    config(
        materialized='ephemeral'
    )
}}

with orders as (
    select * from {{ ref('stg_orders') }}
),
order_aggregates as (
    select * from {{ ref('int_order_aggregates') }}
)

select
    o.customer_id,
    count(distinct o.order_id) as total_orders,
    sum(oa.order_total) as total_spent,
    avg(oa.order_total) as avg_order_value,
    min(o.order_date) as first_order_date,
    max(o.order_date) as last_order_date,
    date_trunc('month', max(o.order_date)) as last_order_month
from orders o
left join order_aggregates oa on o.order_id = oa.order_id
group by o.customer_id