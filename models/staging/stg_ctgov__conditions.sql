-- One row per study and listed condition.

with studies as (

    select * from {{ ref('base_ctgov__studies_latest') }}

)

select
    s.nct_id,
    c.index                                                      as condition_seq,
    c.value::varchar                                             as condition_name
from studies s,
    lateral flatten(input => s.payload:protocolSection:conditionsModule:conditions) c
