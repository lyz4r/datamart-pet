{{
    config(
        materialized='view',
        schema='staging'
    )
}}

select
    id as user_id,
    name as first_name,
    surname as last_name,
    concat(name, ' ', surname) as full_name,
    email,
    birthdate,
    extract(year from age(current_date, birthdate)) as age,
    -- Добавляем сегментацию по возрасту
    case 
        when birthdate is null then 'Unknown'
        when extract(year from age(current_date, birthdate)) < 18 then 'Under 18'
        when extract(year from age(current_date, birthdate)) between 18 and 25 then '18-25'
        when extract(year from age(current_date, birthdate)) between 26 and 35 then '26-35'
        when extract(year from age(current_date, birthdate)) between 36 and 50 then '36-50'
        else '50+'
    end as age_group,
    current_timestamp as loaded_at
from {{ source('eshop', 'users') }}