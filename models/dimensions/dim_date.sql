{{ config(post_hook="ALTER TABLE {{ this }} ADD CONSTRAINT pk_dim_date_{{ invocation_id.replace('-', '')[:8] }} PRIMARY KEY (date_key)") }}

with all_dates as (
    select bite_at::date as full_date
    from {{ ref('int_triage_cases_accepted') }}
    union
    select arrived_at::date as full_date
    from {{ ref('int_triage_cases_accepted') }}
)

select
    to_char(full_date, 'YYYYMMDD')::bigint as date_key,
    full_date,
    trim(to_char(full_date, 'Day')) as day_of_week,
    extract(year from full_date)::smallint as calendar_year,
    extract(quarter from full_date)::smallint as calendar_quarter,
    extract(month from full_date)::smallint as calendar_month,
    trim(to_char(full_date, 'Month')) as month_name,
    extract(day from full_date)::smallint as day_of_month,
    extract(week from full_date)::smallint as iso_week,
    extract(isodow from full_date)::smallint as iso_day_of_week,
    extract(isodow from full_date) in (6, 7) as is_weekend
from all_dates
