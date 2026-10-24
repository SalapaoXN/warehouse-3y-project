{{ config(post_hook="ALTER TABLE {{ this }} ADD CONSTRAINT pk_dim_location_{{ invocation_id.replace('-', '')[:8] }} PRIMARY KEY (location_key)") }}

with members as (
    select distinct
        coalesce(province_name_raw, '__MISSING__') as province_name
    from {{ ref('int_triage_cases_accepted') }}
),
keyed as (
    select
        row_number() over (order by province_name)::bigint as location_key,
        province_name
    from members
)

select
    location_key,
    case when province_name = '__MISSING__' then 'Missing source value' else province_name end
        as province_name
from keyed
