{{ config(materialized='table') }}

with normalized as (
    select
        r.source_row_number::bigint as source_row_number,
        nullif(btrim(r.patient_id), '') as patient_id,
        nullif(btrim(r.age), '') as age_source_value,
        nullif(btrim(r.gender), '') as gender_source_value,
        nullif(btrim(r.time_since_bite_min), '') as source_delay_value,
        nullif(btrim(r.heart_rate_bpm), '') as heart_rate_value,
        nullif(btrim(r.blood_pressure_systolic), '') as systolic_bp_value,
        nullif(btrim(r.local_swelling), '') as swelling_source_value,
        nullif(btrim(r.muscle_paralysis_present), '') as paralysis_value,
        nullif(btrim(r.blood_coagulation_failure), '') as coagulation_value,
        nullif(btrim(r.bite_source_target), '') as bite_source_source_value,
        nullif(btrim(r.bite_timestamp), '') as bite_timestamp_value,
        nullif(btrim(r.arrival_timestamp), '') as arrival_timestamp_value,
        nullif(btrim(r.province), '') as province_source_value,
        nullif(btrim(r.triage_level), '') as triage_level_source_value,
        nullif(btrim(r.bite_position), '') as bite_position_source_value,
        m.source_file_name,
        m.source_file_sha256,
        cast('{{ run_started_at }}' as timestamptz) as loaded_at,
        '{{ invocation_id }}'::text as dbt_invocation_id
    from {{ source('raw', 'raw_triage_case_rows') }} as r
    cross join {{ ref('raw_source_manifest') }} as m
),

typed as (
    select
        *,
        case when pg_input_is_valid(age_source_value, 'integer')
            then age_source_value::integer end as age_at_event,
        case when pg_input_is_valid(source_delay_value, 'numeric')
            then source_delay_value::numeric(12, 4) end as source_time_since_bite_min,
        case when pg_input_is_valid(heart_rate_value, 'numeric')
            then heart_rate_value::numeric(12, 4) end as heart_rate_bpm,
        case when pg_input_is_valid(systolic_bp_value, 'numeric')
            then systolic_bp_value::numeric(12, 4) end as systolic_bp_mmhg,
        case when bite_timestamp_value is not null
                  and pg_input_is_valid(bite_timestamp_value, 'timestamp without time zone')
            then bite_timestamp_value::timestamp without time zone end as bite_at,
        case when arrival_timestamp_value is not null
                  and pg_input_is_valid(arrival_timestamp_value, 'timestamp without time zone')
            then arrival_timestamp_value::timestamp without time zone end as arrived_at,
        case when paralysis_value in ('0', '1')
            then paralysis_value = '1' end as muscle_paralysis_present,
        case when coagulation_value in ('0', '1')
            then coagulation_value = '1' end as blood_coagulation_failure
    from normalized
),

with_delay as (
    select
        *,
        case when bite_at is not null and arrived_at is not null
            then (extract(epoch from (arrived_at - bite_at)) / 60.0)::numeric(12, 4)
        end as calculated_time_since_bite_min
    from typed
),

validated as (
    select
        *,
        nullif(concat_ws(';',
            case when source_row_number is null then 'missing_source_row_number' end,
            case when bite_timestamp_value is null then 'missing_bite_timestamp'
                 when bite_at is null then 'invalid_bite_timestamp' end,
            case when arrival_timestamp_value is null then 'missing_arrival_timestamp'
                 when arrived_at is null then 'invalid_arrival_timestamp' end,
            case when bite_at is not null and arrived_at is not null and arrived_at < bite_at
                then 'arrival_before_bite' end,
            case when age_source_value is not null and age_at_event is null
                then 'invalid_age' end,
            case when source_delay_value is not null and source_time_since_bite_min is null
                then 'invalid_source_delay' end,
            case when heart_rate_value is not null and heart_rate_bpm is null
                then 'invalid_heart_rate' end,
            case when systolic_bp_value is not null and systolic_bp_mmhg is null
                then 'invalid_systolic_bp' end,
            case when paralysis_value is not null and paralysis_value not in ('0', '1')
                then 'invalid_paralysis_flag' end,
            case when coagulation_value is not null and coagulation_value not in ('0', '1')
                then 'invalid_coagulation_flag' end
        ), '') as validation_errors,
        case
            when source_time_since_bite_min is not null
             and calculated_time_since_bite_min is not null
            then source_time_since_bite_min = calculated_time_since_bite_min
        end as delay_matches_timestamp
    from with_delay
)

select
    source_file_name,
    source_file_sha256,
    source_row_number,
    patient_id,
    age_at_event,
    gender_source_value as gender_code,
    source_time_since_bite_min,
    calculated_time_since_bite_min,
    delay_matches_timestamp,
    heart_rate_bpm,
    systolic_bp_mmhg,
    swelling_source_value as swelling_code,
    muscle_paralysis_present,
    blood_coagulation_failure,
    bite_source_source_value as bite_source_code,
    bite_at,
    arrived_at,
    province_source_value as province_name_raw,
    triage_level_source_value as triage_level_code,
    bite_position_source_value as bite_position_code,
    case when validation_errors is null then 'accepted' else 'quarantined' end
        as validation_status,
    validation_errors,
    loaded_at,
    dbt_invocation_id
from validated
