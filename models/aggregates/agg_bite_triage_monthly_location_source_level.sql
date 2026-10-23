select
    date_trunc('month', arrival_date.full_date)::date as arrival_month,
    f.location_key,
    f.bite_source_key,
    f.triage_key,
    count(*)::bigint as patient_count,
    coalesce(sum(f.time_since_bite_min), 0)::numeric(20, 4)
        as source_delay_minutes_sum,
    count(f.time_since_bite_min)::bigint as source_delay_observation_count,
    coalesce(sum(f.heart_rate_bpm), 0)::numeric(20, 4) as heart_rate_sum,
    count(f.heart_rate_bpm)::bigint as heart_rate_observation_count,
    coalesce(sum(f.blood_pressure_systolic), 0)::numeric(20, 4) as systolic_bp_sum,
    count(f.blood_pressure_systolic)::bigint as systolic_bp_observation_count,
    count(*) filter (where symptoms.muscle_paralysis_present is true)::bigint
        as paralysis_positive_count,
    count(symptoms.muscle_paralysis_present)::bigint as paralysis_assessed_count,
    count(*) filter (where symptoms.blood_coagulation_failure is true)::bigint
        as coag_failure_positive_count,
    count(symptoms.blood_coagulation_failure)::bigint as coag_failure_assessed_count
from {{ ref('fact_bite_triage') }} as f
join {{ ref('dim_date') }} as arrival_date
    on f.arrival_date_key = arrival_date.date_key
join {{ ref('dim_symptom_profile') }} as symptoms
    on f.symptom_profile_key = symptoms.symptom_profile_key
group by
    date_trunc('month', arrival_date.full_date)::date,
    f.location_key,
    f.bite_source_key,
    f.triage_key
