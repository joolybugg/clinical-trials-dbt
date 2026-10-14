-- One row per study with site counts and timeline measures.

with studies as (

    select * from {{ ref('stg_ctgov__studies') }}

),

site_counts as (

    select
        nct_id,
        count(*)                                                     as site_count,
        count(distinct country)                                      as country_count,
        count_if(country = 'United States')                          as us_site_count,
        count_if(site_recruitment_status = 'RECRUITING')             as recruiting_site_count
    from {{ ref('stg_ctgov__locations') }}
    group by nct_id

),

collaborator_counts as (

    select nct_id, count(*) as collaborator_count
    from {{ ref('stg_ctgov__collaborators') }}
    group by nct_id

)

select
    s.nct_id,
    s.brief_title,
    s.overall_status,
    s.study_type,
    s.phases,
    s.enrollment_count,
    s.enrollment_type,
    case when s.lead_sponsor_name is not null
         then {{ dbt_utils.generate_surrogate_key(['s.lead_sponsor_name']) }}
    end                                                              as sponsor_id,
    s.lead_sponsor_class,
    s.start_date,
    s.primary_completion_date,
    s.completion_date,
    s.last_update_posted_date,
    datediff('day', s.start_date, s.primary_completion_date)         as days_start_to_primary_completion,
    s.primary_completion_date_type = 'ACTUAL'                        as is_primary_completion_actual,
    coalesce(sc.site_count, 0)                                       as site_count,
    coalesce(sc.country_count, 0)                                    as country_count,
    coalesce(sc.us_site_count, 0)                                    as us_site_count,
    coalesce(sc.recruiting_site_count, 0)                            as recruiting_site_count,
    coalesce(cc.collaborator_count, 0)                               as collaborator_count,
    s.enrollment_count / nullif(sc.site_count, 0)                    as enrollment_per_site
from studies s
left join site_counts sc using (nct_id)
left join collaborator_counts cc using (nct_id)
