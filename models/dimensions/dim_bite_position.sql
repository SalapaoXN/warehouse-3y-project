{{ config(post_hook="ALTER TABLE {{ this }} ADD CONSTRAINT pk_dim_bite_position_{{ invocation_id.replace('-', '')[:8] }} PRIMARY KEY (bite_position_key)") }}

with members as (
    select distinct coalesce(bite_position_code, '__MISSING__') as bite_position_name
    from {{ ref('int_triage_cases_accepted') }}
),
keyed as (
    select
        row_number() over (order by bite_position_name)::bigint as bite_position_key,
        bite_position_name
    from members
)

select
    bite_position_key,
    case when bite_position_name = '__MISSING__' then 'Missing source value' else bite_position_name end
        as bite_position_name
from keyed
