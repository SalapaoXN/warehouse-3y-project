with staging_count as (
    select count(*)::bigint as row_count
    from {{ ref('stg_triage_cases') }}
),
manifest as (
    select max(source_row_count) as expected_rows
    from {{ ref('raw_source_manifest') }}
)

select staging_count.row_count, manifest.expected_rows
from staging_count
cross join manifest
where staging_count.row_count <> manifest.expected_rows
