{{ config(post_hook="ALTER TABLE {{ this }} ADD CONSTRAINT pk_dim_triage_{{ invocation_id.replace('-', '')[:8] }} PRIMARY KEY (triage_key)") }}

with members as (
    select distinct coalesce(triage_level_code, '__MISSING__') as triage_level
    from {{ ref('int_triage_cases_accepted') }}
),
keyed as (
    select
        row_number() over (order by triage_level)::bigint as triage_key,
        triage_level
    from members
)

select
    0::bigint as triage_key,
    '__UNKNOWN__'::text as triage_scale_code,
    '__UNKNOWN__'::text as triage_level,
    'Unknown'::text as triage_level_label,
    null::smallint as severity_rank
union all
select
    triage_key,
    'UNSPECIFIED'::text as triage_scale_code,
    triage_level,
    case when triage_level = '__MISSING__' then 'Missing source value' else triage_level end
        as triage_level_label,
    null::smallint as severity_rank
from keyed
