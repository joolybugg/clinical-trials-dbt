-- One row per study site, joined to study and sponsor attributes so site
-- performance can be sliced by phase, sponsor class, and status.

select
    l.study_site_id,
    l.nct_id,
    {{ dbt_utils.generate_surrogate_key(['l.facility_name', 'l.city', 'l.state', 'l.country']) }} as facility_id,
    l.facility_name,
    l.city,
    l.state,
    l.country,
    l.latitude,
    l.longitude,
    l.site_recruitment_status,
    s.overall_status         as study_status,
    s.phases,
    s.sponsor_id,
    s.lead_sponsor_class,
    s.start_date             as study_start_date,
    s.enrollment_count       as study_enrollment_count
from {{ ref('stg_ctgov__locations') }} l
join {{ ref('fct_studies') }} s using (nct_id)
