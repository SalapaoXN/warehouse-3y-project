with raw_counts as (
    select count(*)::bigint as row_count
    from {{ source('raw', 'raw_triage_case_rows') }}
),
manifest as (
    select count(*)::bigint as manifest_rows, max(source_row_count) as expected_rows
    from {{ ref('raw_source_manifest') }}
)

select
    raw_counts.row_count,
    manifest.manifest_rows,
    manifest.expected_rows
from raw_counts
cross join manifest
where manifest.manifest_rows <> 1
   or raw_counts.row_count <> manifest.expected_rows
