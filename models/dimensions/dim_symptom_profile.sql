{{ config(post_hook="ALTER TABLE {{ this }} ADD CONSTRAINT pk_dim_symptom_profile_{{ invocation_id.replace('-', '')[:8] }} PRIMARY KEY (symptom_profile_key)") }}

with members as (
    select distinct
        swelling_code as local_swelling,
        muscle_paralysis_present,
        blood_coagulation_failure
    from {{ ref('int_triage_cases_accepted') }}
),
keyed as (
    select
        row_number() over (
            order by local_swelling nulls first,
                     muscle_paralysis_present nulls first,
                     blood_coagulation_failure nulls first
        )::bigint as symptom_profile_key,
        local_swelling,
        muscle_paralysis_present,
        blood_coagulation_failure
    from members
)

select
    *,
    concat_ws('; ',
        case
            when local_swelling is null then 'Swelling unknown'
            when lower(local_swelling) = 'none' then 'No swelling'
            else local_swelling || ' swelling'
        end,
        case
            when muscle_paralysis_present then 'Muscle paralysis'
            when muscle_paralysis_present is null then 'Paralysis unknown'
        end,
        case
            when blood_coagulation_failure then 'Blood coagulation failure'
            when blood_coagulation_failure is null then 'Coagulation status unknown'
        end
    ) as symptom_profile_label
from keyed
