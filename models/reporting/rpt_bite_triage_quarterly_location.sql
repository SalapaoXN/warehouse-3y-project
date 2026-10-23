with rolled_up as (
    select
        date_trunc('quarter', a.arrival_month)::date as arrival_quarter,
        a.location_key,
        a.bite_source_key,
        a.triage_key,
        sum(a.patient_count)::bigint as patient_count,
        sum(a.source_delay_minutes_sum)::numeric(20, 4) as source_delay_minutes_sum,
        sum(a.source_delay_observation_count)::bigint as source_delay_observation_count,
        sum(a.calculated_delay_minutes_sum)::numeric(20, 4)
            as calculated_delay_minutes_sum,
        sum(a.calculated_delay_observation_count)::bigint
            as calculated_delay_observation_count,
        sum(a.heart_rate_sum)::numeric(20, 4) as heart_rate_sum,
        sum(a.heart_rate_observation_count)::bigint as heart_rate_observation_count,
        sum(a.systolic_bp_sum)::numeric(20, 4) as systolic_bp_sum,
        sum(a.systolic_bp_observation_count)::bigint as systolic_bp_observation_count,
        sum(a.paralysis_positive_count)::bigint as paralysis_positive_count,
        sum(a.paralysis_assessed_count)::bigint as paralysis_assessed_count,
        sum(a.coag_failure_positive_count)::bigint as coag_failure_positive_count,
        sum(a.coag_failure_assessed_count)::bigint as coag_failure_assessed_count
    from {{ ref('agg_bite_triage_monthly_location_source_level') }} as a
    group by
        date_trunc('quarter', a.arrival_month)::date,
        a.location_key,
        a.bite_source_key,
        a.triage_key
)

select
    r.arrival_quarter,
    l.province_name as location,
    s.bite_source_name as bite_source,
    t.triage_scale_code,
    t.triage_level_label,
    r.patient_count,
    r.source_delay_minutes_sum
        / nullif(r.source_delay_observation_count, 0) as avg_source_delay_min,
    r.calculated_delay_minutes_sum
        / nullif(r.calculated_delay_observation_count, 0) as avg_calculated_delay_min,
    r.heart_rate_sum / nullif(r.heart_rate_observation_count, 0) as avg_heart_rate_bpm,
    r.systolic_bp_sum / nullif(r.systolic_bp_observation_count, 0) as avg_systolic_bp_mmhg,
    r.paralysis_positive_count,
    r.paralysis_assessed_count,
    r.paralysis_positive_count::numeric / nullif(r.paralysis_assessed_count, 0)
        as paralysis_share,
    r.coag_failure_positive_count,
    r.coag_failure_assessed_count,
    r.coag_failure_positive_count::numeric / nullif(r.coag_failure_assessed_count, 0)
        as coag_failure_share
from rolled_up as r
join {{ ref('dim_location') }} as l using (location_key)
join {{ ref('dim_bite_source') }} as s using (bite_source_key)
join {{ ref('dim_triage') }} as t using (triage_key)
