-- One row per study, latest load only, with dates normalized.

with latest as (

    select * from {{ ref('base_ctgov__studies_latest') }}

),

renamed as (

    select
        p:identificationModule:nctId::varchar                                as nct_id,
        p:identificationModule:briefTitle::varchar                           as brief_title,
        p:statusModule:overallStatus::varchar                                as overall_status,
        p:designModule:studyType::varchar                                    as study_type,
        array_to_string(p:designModule:phases, ', ')                         as phases,
        p:designModule:enrollmentInfo:count::int                             as enrollment_count,
        p:designModule:enrollmentInfo:type::varchar                          as enrollment_type,
        p:sponsorCollaboratorsModule:leadSponsor:name::varchar               as lead_sponsor_name,
        p:sponsorCollaboratorsModule:leadSponsor:class::varchar              as lead_sponsor_class,

        {{ parse_ctgov_date('p:statusModule:startDateStruct:date::varchar') }}             as start_date,
        {{ parse_ctgov_date('p:statusModule:primaryCompletionDateStruct:date::varchar') }} as primary_completion_date,
        {{ parse_ctgov_date('p:statusModule:completionDateStruct:date::varchar') }}        as completion_date,
        {{ parse_ctgov_date('p:statusModule:lastUpdatePostDateStruct:date::varchar') }}    as last_update_posted_date,
        p:statusModule:primaryCompletionDateStruct:type::varchar             as primary_completion_date_type,

        loaded_at
    from (
        select payload:protocolSection as p, loaded_at
        from latest
    )

)

select * from renamed
