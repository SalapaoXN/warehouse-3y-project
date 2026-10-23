-- Design reference for the current Silent Sting dbt patient-grain star schema.
-- The dbt models, not this DDL, create and refresh the executable warehouse.
-- patient_id is the requested snapshot grain; restrict access to this identifier.

CREATE SCHEMA IF NOT EXISTS ss_raw;
CREATE SCHEMA IF NOT EXISTS ss_stg;
CREATE SCHEMA IF NOT EXISTS ss_dw;
CREATE SCHEMA IF NOT EXISTS ss_mart;

CREATE TABLE IF NOT EXISTS ss_dw.dim_date (
    date_key bigint PRIMARY KEY,
    full_date date NOT NULL UNIQUE,
    day_of_week text NOT NULL,
    calendar_year smallint NOT NULL,
    calendar_quarter smallint NOT NULL CHECK (calendar_quarter BETWEEN 1 AND 4),
    calendar_month smallint NOT NULL CHECK (calendar_month BETWEEN 1 AND 12),
    month_name text NOT NULL,
    day_of_month smallint NOT NULL CHECK (day_of_month BETWEEN 1 AND 31),
    iso_week smallint NOT NULL CHECK (iso_week BETWEEN 1 AND 53),
    iso_day_of_week smallint NOT NULL CHECK (iso_day_of_week BETWEEN 1 AND 7),
    is_weekend boolean NOT NULL
);

CREATE TABLE IF NOT EXISTS ss_dw.dim_location (
    location_key bigint PRIMARY KEY,
    province_code text NOT NULL UNIQUE,
    province_name text NOT NULL,
    region_name text
);

CREATE TABLE IF NOT EXISTS ss_dw.dim_bite_source (
    bite_source_key bigint PRIMARY KEY,
    source_code text NOT NULL UNIQUE,
    bite_source_name text NOT NULL
);

CREATE TABLE IF NOT EXISTS ss_dw.dim_bite_position (
    bite_position_key bigint PRIMARY KEY,
    position_code text NOT NULL UNIQUE,
    bite_position_name text NOT NULL
);

CREATE TABLE IF NOT EXISTS ss_dw.dim_symptom_profile (
    symptom_profile_key bigint PRIMARY KEY,
    local_swelling text,
    muscle_paralysis_present boolean,
    blood_coagulation_failure boolean
);

CREATE TABLE IF NOT EXISTS ss_dw.dim_triage (
    triage_key bigint PRIMARY KEY,
    triage_scale_code text NOT NULL,
    triage_level text NOT NULL,
    triage_level_label text NOT NULL,
    severity_rank smallint
);

CREATE TABLE IF NOT EXISTS ss_dw.fact_bite_triage (
    patient_id text PRIMARY KEY,
    source_batch_id uuid NOT NULL,
    source_file_sha256 text NOT NULL,
    source_row_number bigint NOT NULL UNIQUE CHECK (source_row_number > 0),
    bite_date_key bigint NOT NULL REFERENCES ss_dw.dim_date (date_key),
    arrival_date_key bigint NOT NULL REFERENCES ss_dw.dim_date (date_key),
    location_key bigint NOT NULL REFERENCES ss_dw.dim_location (location_key),
    bite_source_key bigint NOT NULL REFERENCES ss_dw.dim_bite_source (bite_source_key),
    bite_position_key bigint NOT NULL REFERENCES ss_dw.dim_bite_position (bite_position_key),
    symptom_profile_key bigint NOT NULL REFERENCES ss_dw.dim_symptom_profile (symptom_profile_key),
    triage_key bigint NOT NULL REFERENCES ss_dw.dim_triage (triage_key),
    age smallint,
    gender text,
    bite_timestamp timestamp without time zone NOT NULL,
    arrival_timestamp timestamp without time zone NOT NULL,
    time_since_bite_min numeric(12, 4),
    calculated_time_since_bite_min numeric(12, 4),
    heart_rate_bpm numeric(12, 4),
    blood_pressure_systolic numeric(12, 4),
    patient_count smallint NOT NULL DEFAULT 1 CHECK (patient_count = 1),
    loaded_at timestamptz NOT NULL,
    dbt_invocation_id text NOT NULL,
    CHECK (arrival_timestamp >= bite_timestamp)
);

CREATE INDEX IF NOT EXISTS ix_fact_bite_triage_arrival_location
    ON ss_dw.fact_bite_triage (arrival_date_key, location_key);
CREATE INDEX IF NOT EXISTS ix_fact_bite_triage_source_triage
    ON ss_dw.fact_bite_triage (bite_source_key, triage_key);

-- Grain: arrival month x location x bite source x triage.
CREATE TABLE IF NOT EXISTS ss_mart.agg_bite_triage_monthly_location_source_level (
    arrival_month date NOT NULL CHECK (EXTRACT(DAY FROM arrival_month) = 1),
    location_key bigint NOT NULL REFERENCES ss_dw.dim_location (location_key),
    bite_source_key bigint NOT NULL REFERENCES ss_dw.dim_bite_source (bite_source_key),
    triage_key bigint NOT NULL REFERENCES ss_dw.dim_triage (triage_key),
    patient_count bigint NOT NULL CHECK (patient_count >= 0),
    source_delay_minutes_sum numeric(20, 4) NOT NULL DEFAULT 0,
    source_delay_observation_count bigint NOT NULL DEFAULT 0,
    calculated_delay_minutes_sum numeric(20, 4) NOT NULL DEFAULT 0,
    calculated_delay_observation_count bigint NOT NULL DEFAULT 0,
    heart_rate_sum numeric(20, 4) NOT NULL DEFAULT 0,
    heart_rate_observation_count bigint NOT NULL DEFAULT 0,
    systolic_bp_sum numeric(20, 4) NOT NULL DEFAULT 0,
    systolic_bp_observation_count bigint NOT NULL DEFAULT 0,
    paralysis_positive_count bigint NOT NULL DEFAULT 0,
    paralysis_assessed_count bigint NOT NULL DEFAULT 0,
    coag_failure_positive_count bigint NOT NULL DEFAULT 0,
    coag_failure_assessed_count bigint NOT NULL DEFAULT 0,
    PRIMARY KEY (arrival_month, location_key, bite_source_key, triage_key)
);
