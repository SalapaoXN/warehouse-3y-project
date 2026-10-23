select
    source_time_since_bite_min,
    ((extract(epoch from (arrived_at - bite_at)) / 60.0)::numeric(12, 4))
        as calculated_from_timestamps
from {{ ref('int_triage_cases_accepted') }}
where source_time_since_bite_min is not null
  and bite_at is not null
  and arrived_at is not null
  and source_time_since_bite_min is distinct from
      ((extract(epoch from (arrived_at - bite_at)) / 60.0)::numeric(12, 4))
limit 100
