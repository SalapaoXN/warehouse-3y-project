with accepted as (
    select *
    from {{ ref('int_triage_cases_accepted') }}
)

select
    a.patient_id,
    md5(a.source_file_sha256)::uuid as source_batch_id,
    a.source_file_sha256,
    a.source_row_number,
    bite_date.date_key as bite_date_key,
    arrival_date.date_key as arrival_date_key,
    location.location_key,
    bite_source.bite_source_key,
    bite_position.bite_position_key,
    symptom_profile.symptom_profile_key,
    triage.triage_key,
    a.age_at_event as age,
    a.gender_code as gender,
    a.bite_at as bite_timestamp,
    a.arrived_at as arrival_timestamp,
    a.source_time_since_bite_min as time_since_bite_min,
    a.calculated_time_since_bite_min,
    a.heart_rate_bpm,
    a.systolic_bp_mmhg as blood_pressure_systolic,
    1::smallint as patient_count,
    a.loaded_at,
    a.dbt_invocation_id
from accepted as a
join {{ ref('dim_date') }} as bite_date
    on a.bite_at::date = bite_date.full_date
join {{ ref('dim_date') }} as arrival_date
    on a.arrived_at::date = arrival_date.full_date
join {{ ref('dim_location') }} as location
    on coalesce(a.province_name_raw, '__MISSING__') = location.province_code
join {{ ref('dim_bite_source') }} as bite_source
    on coalesce(a.bite_source_code, '__MISSING__') = bite_source.source_code
join {{ ref('dim_bite_position') }} as bite_position
    on coalesce(a.bite_position_code, '__MISSING__') = bite_position.position_code
join {{ ref('dim_symptom_profile') }} as symptom_profile
    on a.swelling_code is not distinct from symptom_profile.local_swelling
   and a.muscle_paralysis_present is not distinct from symptom_profile.muscle_paralysis_present
   and a.blood_coagulation_failure is not distinct from symptom_profile.blood_coagulation_failure
join {{ ref('dim_triage') }} as triage
    on triage.triage_scale_code = 'UNSPECIFIED'
   and coalesce(a.triage_level_code, '__MISSING__') = triage.triage_level
