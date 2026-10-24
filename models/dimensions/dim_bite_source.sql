{{ config(post_hook="ALTER TABLE {{ this }} ADD CONSTRAINT pk_dim_bite_source_{{ invocation_id.replace('-', '')[:8] }} PRIMARY KEY (bite_source_key)") }}

with members as (
    select distinct coalesce(bite_source_code, '__MISSING__') as bite_source_name
    from {{ ref('int_triage_cases_accepted') }}
),
keyed as (
    select
        row_number() over (order by bite_source_name)::bigint as bite_source_key,
        bite_source_name
    from members
)

select
    bite_source_key,
    case when bite_source_name = '__MISSING__' then 'Missing source value' else bite_source_name end
        as bite_source_name
from keyed
