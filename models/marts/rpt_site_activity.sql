-- Reporting model: which US research sites carry the heaviest trial load,
-- and how much of it comes from industry sponsors. This is the kind of
-- question a site-network or IRB team asks when planning capacity.

select
    facility_id,
    any_value(facility_name)                                         as facility_name,
    any_value(city)                                                  as city,
    any_value(state)                                                 as state,
    count(distinct nct_id)                                           as study_count,
    count(distinct case when site_recruitment_status = 'RECRUITING' then nct_id end) as recruiting_study_count,
    count(distinct sponsor_id)                                       as distinct_sponsor_count,
    count(distinct case when lead_sponsor_class = 'INDUSTRY' then nct_id end)
        / nullif(count(distinct nct_id), 0)                          as industry_share,
    min(study_start_date)                                            as first_study_start_date,
    max(study_start_date)                                            as latest_study_start_date
from {{ ref('fct_study_sites') }}
where country = 'United States'
  and facility_name is not null
group by facility_id
