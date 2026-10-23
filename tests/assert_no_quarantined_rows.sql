select count(*)::bigint as quarantined_rows
from {{ ref('int_triage_cases_quarantined') }}
having count(*) > 0
