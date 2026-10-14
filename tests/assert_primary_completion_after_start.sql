-- A study's primary completion should not precede its start. Rows returned
-- here are data-quality findings to investigate, not pipeline failures,
-- so this test warns rather than errors.
{{ config(severity='warn') }}

select nct_id, start_date, primary_completion_date
from {{ ref('fct_studies') }}
where primary_completion_date < start_date
