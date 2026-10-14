{{ config(materialized='ephemeral') }}

-- Repeated loads append to the raw table. Keep only the most recently
-- loaded version of each study so every downstream model shares one rule.

select
    payload,
    payload:protocolSection:identificationModule:nctId::varchar as nct_id,
    loaded_at
from {{ source('ctgov', 'studies_raw') }}
qualify row_number() over (
    partition by payload:protocolSection:identificationModule:nctId::varchar
    order by loaded_at desc
) = 1
