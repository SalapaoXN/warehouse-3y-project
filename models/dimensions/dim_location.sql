with members as (
    select distinct
        coalesce(province_name_raw, '__MISSING__') as province_code
    from {{ ref('int_triage_cases_accepted') }}
),
keyed as (
    select
        row_number() over (order by province_code)::bigint as location_key,
        province_code
    from members
)

select
    0::bigint as location_key,
    '__UNKNOWN__'::text as province_code,
    'Unknown'::text as province_name,
    null::text as region_name
union all
select
    location_key,
    province_code,
    case when province_code = '__MISSING__' then 'Missing source value' else province_code end,
    null::text as region_name
from keyed
