select
    arrival_month,
    location_key,
    bite_source_key,
    triage_key,
    count(*) as rows_at_grain
from {{ ref('agg_bite_triage_monthly_location_source_level') }}
group by
    arrival_month,
    location_key,
    bite_source_key,
    triage_key
having count(*) > 1
