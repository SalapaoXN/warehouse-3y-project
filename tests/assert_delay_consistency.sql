select
    source_row_number,
    source_time_since_bite_min,
    calculated_time_since_bite_min
from {{ ref('int_triage_cases_accepted') }}
where source_time_since_bite_min is not null
  and calculated_time_since_bite_min is not null
  and delay_matches_timestamp is false
limit 100
