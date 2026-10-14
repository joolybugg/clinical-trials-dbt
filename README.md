# Clinical Trials Analytics (dbt + Snowflake)

An ELT pipeline that loads public study registrations from the ClinicalTrials.gov v2 API into Snowflake and models them with dbt into sponsor, study, and research-site marts. The reporting layer answers a site-capacity question: which US research sites carry the heaviest trial load, and how much of it comes from industry sponsors.

## Architecture
<img width="1463" height="740" alt="image" src="https://github.com/user-attachments/assets/62997682-bf99-48c1-85b6-37cd12461dcd" />


```
ClinicalTrials.gov API v2
        │  ingest/load_studies.py  (paginate → gzip NDJSON → PUT → COPY INTO)
        ▼
CTGOV_RAW.CTGOV.STUDIES_RAW        raw JSON as VARIANT, append-only, one row per load
        │  dbt
        ▼
staging   base_ctgov__studies_latest   dedup to latest load per NCT ID (ephemeral)
          stg_ctgov__studies           typed study attributes, normalized dates
          stg_ctgov__locations         LATERAL FLATTEN of the sites array
          stg_ctgov__conditions        one row per study and condition
          stg_ctgov__collaborators     one row per study and collaborator
        ▼
marts     fct_studies                  study grain with site and timeline measures
          dim_sponsors                 lead sponsor portfolio
          fct_study_sites              study × site grain
          rpt_site_activity            US facility trial load and sponsor mix
```

## Design decisions

- **Land raw, transform in the warehouse.** The loader does no parsing. The full API record lands as VARIANT, so a schema change upstream never breaks ingestion, and any field can be modeled later without reloading.
- **Append-only raw, deduplicate once.** Each load appends. A single ephemeral base model keeps the latest version of each study, so every downstream model shares one dedup rule.
- **Partial dates handled explicitly.** The registry reports dates at month or day precision. The `parse_ctgov_date` macro normalizes both, and `is_primary_completion_actual` separates actual from anticipated completion dates.
- **Tests at every layer.** Uniqueness and not-null on keys, accepted values on status and sponsor class, referential integrity from sites to studies and studies to sponsors, numeric range checks, source freshness, and a singular test that flags studies whose completion precedes their start.
- **CI on every pull request.** GitHub Actions runs `dbt build` in an isolated CI schema, so a broken model or failing test blocks the merge.

## Setup

1. **Snowflake.** Start a free trial account. In a Snowsight worksheet, run `setup/snowflake_setup.sql` after replacing `<YOUR_USERNAME>`.
2. **Key pair.** Generate one, then register the public key in Snowflake (the last statement in the setup script):
   ```bash
   mkdir -p ~/.snowflake && cd ~/.snowflake
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
   openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
   chmod 600 rsa_key.p8
   ```
3. **Python environment** (Python 3.10 or newer):
   ```bash
   python3 -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
   cp .env.example .env              # fill in account, user, key path
   mkdir -p ~/.dbt && cp profiles.example.yml ~/.dbt/profiles.yml
   ```
4. **Load data:**
   ```bash
   python ingest/load_studies.py --condition "diabetes" --max-pages 5
   ```
5. **Build and test:**
   ```bash
   set -a && source .env && set +a   # export credentials for dbt
   dbt deps
   dbt build
   dbt source freshness
   dbt docs generate && dbt docs serve
   ```
6. **CI.** Add `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, and `SNOWFLAKE_PRIVATE_KEY` (the full contents of `rsa_key.p8`) as repository secrets in GitHub.

## Example questions the marts answer

```sql
-- US sites with the most active trials and their industry mix
select facility_name, city, state, study_count, recruiting_study_count, industry_share
from dev_marts.rpt_site_activity
order by study_count desc
limit 20;

-- Median start-to-primary-completion time by phase, actual completions only
select phases, median(days_start_to_primary_completion) as median_days, count(*) as studies
from dev_marts.fct_studies
where is_primary_completion_actual
group by phases
order by studies desc;
```

## Data source

Study records come from the public [ClinicalTrials.gov API v2](https://clinicaltrials.gov/data-api/api), maintained by the U.S. National Library of Medicine.
