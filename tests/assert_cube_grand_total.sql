with cube_total as (
    select count(*)::bigint as total_rows, max(patient_count)::bigint as patient_count
    from {{ ref('rpt_bite_triage_location_source_level_cube') }}
    where is_all_locations and is_all_bite_sources and is_all_triage_levels
),
fact_total as (
    select count(*)::bigint as patient_count
    from {{ ref('fact_bite_triage') }}
)

select cube_total.total_rows, cube_total.patient_count, fact_total.patient_count as fact_patient_count
from cube_total
cross join fact_total
where cube_total.total_rows <> 1
   or cube_total.patient_count is distinct from fact_total.patient_count
