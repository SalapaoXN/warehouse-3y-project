select *
from {{ ref('stg_triage_cases') }}
where validation_status = 'accepted'
