{{ config(post_hook="ALTER TABLE {{ this }} ADD CONSTRAINT pk_dim_triage_{{ invocation_id.replace('-', '')[:8] }} PRIMARY KEY (triage_key)") }}

with members as (
    select distinct triage_level_number as triage_level
    from {{ ref('int_triage_cases_accepted') }}
),
keyed as (
    select
        row_number() over (order by triage_level)::bigint as triage_key,
        triage_level
    from members
)

select
    triage_key,
    triage_level
from keyed
