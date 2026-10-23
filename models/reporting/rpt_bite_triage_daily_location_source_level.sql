select
    arrival_date.full_date as arrival_date,
    l.province_name as location,
    s.bite_source_name as bite_source,
    t.triage_scale_code,
    t.triage_level_label,
    count(*)::bigint as patient_count,
    avg(f.time_since_bite_min) as avg_source_delay_min,
    avg(f.heart_rate_bpm) as avg_heart_rate_bpm,
    avg(f.blood_pressure_systolic) as avg_systolic_bp_mmhg,
    count(*) filter (where symptoms.muscle_paralysis_present is true)::bigint
        as paralysis_positive_count,
    count(symptoms.muscle_paralysis_present)::bigint as paralysis_assessed_count,
    count(*) filter (where symptoms.blood_coagulation_failure is true)::bigint
        as coag_failure_positive_count,
    count(symptoms.blood_coagulation_failure)::bigint as coag_failure_assessed_count
from {{ ref('fact_bite_triage') }} as f
join {{ ref('dim_date') }} as arrival_date
    on f.arrival_date_key = arrival_date.date_key
join {{ ref('dim_location') }} as l using (location_key)
join {{ ref('dim_bite_source') }} as s using (bite_source_key)
join {{ ref('dim_triage') }} as t using (triage_key)
join {{ ref('dim_symptom_profile') }} as symptoms using (symptom_profile_key)
group by
    arrival_date.full_date,
    l.province_name,
    s.bite_source_name,
    t.triage_scale_code,
    t.triage_level_label
