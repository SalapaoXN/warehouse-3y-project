{{ config(post_hook="ALTER TABLE {{ this }} ADD CONSTRAINT pk_dim_bite_source_{{ invocation_id.replace('-', '')[:8] }} PRIMARY KEY (bite_source_key)") }}

with members as (
    select distinct coalesce(bite_source_code, '__MISSING__') as source_code
    from {{ ref('int_triage_cases_accepted') }}
),
keyed as (
    select
        row_number() over (order by source_code)::bigint as bite_source_key,
        source_code
    from members
)

select
    0::bigint as bite_source_key,
    '__UNKNOWN__'::text as source_code,
    'Unknown'::text as bite_source_name
union all
select
    bite_source_key,
    source_code,
    case when source_code = '__MISSING__' then 'Missing source value' else source_code end
        as bite_source_name
from keyed
