-- One row per study site. Flattens the locations array; a study can list
-- hundreds of sites, which is the grain Advarra-style site analytics need.

with studies as (

    select * from {{ ref('base_ctgov__studies_latest') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['s.nct_id', 'loc.index']) }} as study_site_id,
    s.nct_id,
    loc.index                                                    as location_seq,
    trim(loc.value:facility::varchar)                            as facility_name,
    loc.value:city::varchar                                      as city,
    loc.value:state::varchar                                     as state,
    loc.value:zip::varchar                                       as zip,
    loc.value:country::varchar                                   as country,
    loc.value:status::varchar                                    as site_recruitment_status,
    loc.value:geoPoint:lat::float                                as latitude,
    loc.value:geoPoint:lon::float                                as longitude
from studies s,
    lateral flatten(input => s.payload:protocolSection:contactsLocationsModule:locations) loc
