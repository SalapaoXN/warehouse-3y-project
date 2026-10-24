select
    a.arrival_month,
    l.province_name as location,
    s.bite_source_name as bite_source,
    t.triage_level,
    a.patient_count,
    a.source_delay_minutes_sum
        / nullif(a.source_delay_observation_count, 0) as avg_source_delay_min,
    a.heart_rate_sum / nullif(a.heart_rate_observation_count, 0) as avg_heart_rate_bpm,
    a.systolic_bp_sum / nullif(a.systolic_bp_observation_count, 0) as avg_systolic_bp_mmhg,
    a.paralysis_positive_count,
    a.paralysis_assessed_count,
    a.paralysis_positive_count::numeric
        / nullif(a.paralysis_assessed_count, 0) as paralysis_share,
    a.coag_failure_positive_count,
    a.coag_failure_assessed_count,
    a.coag_failure_positive_count::numeric
        / nullif(a.coag_failure_assessed_count, 0) as coag_failure_share
from {{ ref('agg_bite_triage_monthly_location_source_level') }} as a
join {{ ref('dim_location') }} as l using (location_key)
join {{ ref('dim_bite_source') }} as s using (bite_source_key)
join {{ ref('dim_triage') }} as t using (triage_key)
