-- Проверка, что revenue положительный
select *
from {{ ref('fct_sales') }}
where revenue <= 0