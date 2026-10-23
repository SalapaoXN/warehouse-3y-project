with cube_rows as (
    select
        grouping(f.location_key) = 1 as is_all_locations,
        case when grouping(f.location_key) = 1 then null::bigint else f.location_key end
            as location_key,
        grouping(f.bite_source_key) = 1 as is_all_bite_sources,
        case when grouping(f.bite_source_key) = 1 then null::bigint else f.bite_source_key end
            as bite_source_key,
        grouping(f.triage_key) = 1 as is_all_triage_levels,
        case when grouping(f.triage_key) = 1 then null::bigint else f.triage_key end
            as triage_key,
        count(*)::bigint as patient_count,
        count(*) filter (where symptoms.muscle_paralysis_present is true)::bigint
            as paralysis_positive_count,
        count(symptoms.muscle_paralysis_present)::bigint as paralysis_assessed_count,
        count(*) filter (where symptoms.blood_coagulation_failure is true)::bigint
            as coag_failure_positive_count,
        count(symptoms.blood_coagulation_failure)::bigint as coag_failure_assessed_count
    from {{ ref('fact_bite_triage') }} as f
    join {{ ref('dim_symptom_profile') }} as symptoms using (symptom_profile_key)
    group by cube (f.location_key, f.bite_source_key, f.triage_key)
)

select
    c.is_all_locations,
    c.location_key,
    case when c.is_all_locations then 'ALL' else l.province_name end as location,
    c.is_all_bite_sources,
    c.bite_source_key,
    case when c.is_all_bite_sources then 'ALL' else s.bite_source_name end as bite_source,
    c.is_all_triage_levels,
    c.triage_key,
    case when c.is_all_triage_levels then 'ALL' else t.triage_level_label end
        as triage_level,
    c.patient_count,
    c.paralysis_positive_count,
    c.paralysis_assessed_count,
    c.paralysis_positive_count::numeric / nullif(c.paralysis_assessed_count, 0)
        as paralysis_share,
    c.coag_failure_positive_count,
    c.coag_failure_assessed_count,
    c.coag_failure_positive_count::numeric / nullif(c.coag_failure_assessed_count, 0)
        as coag_failure_share
from cube_rows as c
left join {{ ref('dim_location') }} as l using (location_key)
left join {{ ref('dim_bite_source') }} as s using (bite_source_key)
left join {{ ref('dim_triage') }} as t using (triage_key)
