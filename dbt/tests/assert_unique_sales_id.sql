-- Проверка уникальности sales_id
select
    sales_id,
    count(*) as duplicate_count
from {{ ref('fct_sales') }}
group by sales_id
having count(*) > 1