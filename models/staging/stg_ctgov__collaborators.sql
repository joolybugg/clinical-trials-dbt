-- One row per study and collaborating organization (often the CRO or an
-- academic partner working alongside the lead sponsor).

with studies as (

    select * from {{ ref('base_ctgov__studies_latest') }}

)

select
    s.nct_id,
    c.index                                                      as collaborator_seq,
    c.value:name::varchar                                        as collaborator_name,
    c.value:class::varchar                                       as collaborator_class
from studies s,
    lateral flatten(input => s.payload:protocolSection:sponsorCollaboratorsModule:collaborators) c
