with fact_totals as (
    select
        count(*)::bigint as patient_count,
        coalesce(sum(f.time_since_bite_min), 0)::numeric as source_delay_sum,
        count(f.time_since_bite_min)::bigint as source_delay_count,
        coalesce(sum(f.heart_rate_bpm), 0)::numeric as heart_rate_sum,
        count(f.heart_rate_bpm)::bigint as heart_rate_count,
        coalesce(sum(f.blood_pressure_systolic), 0)::numeric as systolic_bp_sum,
        count(f.blood_pressure_systolic)::bigint as systolic_bp_count,
        count(*) filter (where symptoms.muscle_paralysis_present is true)::bigint
            as paralysis_positive,
        count(symptoms.muscle_paralysis_present)::bigint as paralysis_assessed,
        count(*) filter (where symptoms.blood_coagulation_failure is true)::bigint
            as coag_failure_positive,
        count(symptoms.blood_coagulation_failure)::bigint as coag_failure_assessed
    from {{ ref('fact_bite_triage') }} as f
    join {{ ref('dim_symptom_profile') }} as symptoms using (symptom_profile_key)
),
aggregate_totals as (
    select
        coalesce(sum(patient_count), 0)::bigint as patient_count,
        coalesce(sum(source_delay_minutes_sum), 0)::numeric as source_delay_sum,
        coalesce(sum(source_delay_observation_count), 0)::bigint as source_delay_count,
        coalesce(sum(heart_rate_sum), 0)::numeric as heart_rate_sum,
        coalesce(sum(heart_rate_observation_count), 0)::bigint as heart_rate_count,
        coalesce(sum(systolic_bp_sum), 0)::numeric as systolic_bp_sum,
        coalesce(sum(systolic_bp_observation_count), 0)::bigint as systolic_bp_count,
        coalesce(sum(paralysis_positive_count), 0)::bigint as paralysis_positive,
        coalesce(sum(paralysis_assessed_count), 0)::bigint as paralysis_assessed,
        coalesce(sum(coag_failure_positive_count), 0)::bigint as coag_failure_positive,
        coalesce(sum(coag_failure_assessed_count), 0)::bigint as coag_failure_assessed
    from {{ ref('agg_bite_triage_monthly_location_source_level') }}
)

select *
from fact_totals as f
cross join aggregate_totals as a
where f.patient_count is distinct from a.patient_count
   or f.source_delay_sum is distinct from a.source_delay_sum
   or f.source_delay_count is distinct from a.source_delay_count
   or f.heart_rate_sum is distinct from a.heart_rate_sum
   or f.heart_rate_count is distinct from a.heart_rate_count
   or f.systolic_bp_sum is distinct from a.systolic_bp_sum
   or f.systolic_bp_count is distinct from a.systolic_bp_count
   or f.paralysis_positive is distinct from a.paralysis_positive
   or f.paralysis_assessed is distinct from a.paralysis_assessed
   or f.coag_failure_positive is distinct from a.coag_failure_positive
   or f.coag_failure_assessed is distinct from a.coag_failure_assessed
