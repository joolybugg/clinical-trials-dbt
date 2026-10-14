{#
  ClinicalTrials.gov publishes dates at either month precision ("2023-05")
  or day precision ("2023-05-15"). Month-only values are pinned to the
  first of the month so they cast cleanly; the precision is kept in a
  separate column by the caller where it matters.
#}
{% macro parse_ctgov_date(column) %}
    try_to_date(
        case
            when length({{ column }}) = 7 then {{ column }} || '-01'
            else {{ column }}
        end
    )
{% endmacro %}
