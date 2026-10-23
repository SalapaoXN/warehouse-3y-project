-- Metabase-friendly row-level view. Keeps the patient grain while resolving
-- warehouse surrogate keys to readable dimension values.
select
    bite_date.full_date as bite_date,
    arrival_date.full_date as arrival_date,
    location.province_name as province,
    source.bite_source_name as bite_source,
    bite_position.bite_position_name as bite_position,
    triage.triage_scale_code,
    triage.triage_level_label as triage_level,
    symptoms.local_swelling,
    symptoms.muscle_paralysis_present,
    symptoms.blood_coagulation_failure,
    fact.age,
    fact.gender,
    fact.bite_timestamp,
    fact.arrival_timestamp,
    fact.time_since_bite_min,
    fact.calculated_time_since_bite_min,
    fact.heart_rate_bpm,
    fact.blood_pressure_systolic,
    fact.patient_count
from {{ ref('fact_bite_triage') }} as fact
join {{ ref('dim_date') }} as bite_date
    on fact.bite_date_key = bite_date.date_key
join {{ ref('dim_date') }} as arrival_date
    on fact.arrival_date_key = arrival_date.date_key
join {{ ref('dim_location') }} as location
    on fact.location_key = location.location_key
join {{ ref('dim_bite_source') }} as source
    on fact.bite_source_key = source.bite_source_key
join {{ ref('dim_bite_position') }} as bite_position
    on fact.bite_position_key = bite_position.bite_position_key
join {{ ref('dim_symptom_profile') }} as symptoms
    on fact.symptom_profile_key = symptoms.symptom_profile_key
join {{ ref('dim_triage') }} as triage
    on fact.triage_key = triage.triage_key
