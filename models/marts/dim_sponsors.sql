-- One row per lead sponsor with portfolio-level measures.

select
    {{ dbt_utils.generate_surrogate_key(['lead_sponsor_name']) }}   as sponsor_id,
    lead_sponsor_name                                               as sponsor_name,
    any_value(lead_sponsor_class)                                   as sponsor_class,
    count(*)                                                        as study_count,
    count_if(overall_status = 'RECRUITING')                         as recruiting_study_count,
    count_if(overall_status = 'COMPLETED')                          as completed_study_count,
    sum(enrollment_count)                                           as total_enrollment,
    min(start_date)                                                 as first_study_start_date,
    max(start_date)                                                 as latest_study_start_date
from {{ ref('stg_ctgov__studies') }}
where lead_sponsor_name is not null
group by lead_sponsor_name
