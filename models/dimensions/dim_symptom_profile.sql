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

select *
from keyed
