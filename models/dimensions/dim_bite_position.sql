{{ config(post_hook="ALTER TABLE {{ this }} ADD CONSTRAINT pk_dim_bite_position_{{ invocation_id.replace('-', '')[:8] }} PRIMARY KEY (bite_position_key)") }}

with members as (
    select distinct coalesce(bite_position_code, '__MISSING__') as position_code
    from {{ ref('int_triage_cases_accepted') }}
),
keyed as (
    select
        row_number() over (order by position_code)::bigint as bite_position_key,
        position_code
    from members
)

select
    0::bigint as bite_position_key,
    '__UNKNOWN__'::text as position_code,
    'Unknown'::text as bite_position_name
union all
select
    bite_position_key,
    position_code,
    case when position_code = '__MISSING__' then 'Missing source value' else position_code end
        as bite_position_name
from keyed
