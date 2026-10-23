with accepted as (
    select count(*)::bigint as row_count
    from {{ ref('int_triage_cases_accepted') }}
),
fact as (
    select count(*)::bigint as row_count
    from {{ ref('fact_bite_triage') }}
)

select accepted.row_count as accepted_rows, fact.row_count as fact_rows
from accepted
cross join fact
where accepted.row_count <> fact.row_count
