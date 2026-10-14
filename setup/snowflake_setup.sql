-- Run once in a Snowsight worksheet as ACCOUNTADMIN on a Snowflake trial account.
-- Creates a small warehouse, a raw landing database, an analytics database,
-- and a least-privilege role that both the loader and dbt use.

use role accountadmin;

create warehouse if not exists ctgov_wh
  warehouse_size = 'XSMALL'
  auto_suspend = 60
  auto_resume = true
  initially_suspended = true;

create database if not exists ctgov_raw;
create schema if not exists ctgov_raw.ctgov;

create database if not exists ctgov_analytics;

create role if not exists transformer;
grant usage on warehouse ctgov_wh to role transformer;
grant all on database ctgov_raw to role transformer;
grant all on schema ctgov_raw.ctgov to role transformer;
grant all on database ctgov_analytics to role transformer;

-- Replace with your Snowflake username.
grant role transformer to user <YOUR_USERNAME>;
alter user <YOUR_USERNAME> set default_role = transformer default_warehouse = ctgov_wh;

-- Key-pair authentication for the loader and dbt (password logins require MFA).
-- Paste the contents of rsa_key.pub WITHOUT the BEGIN/END lines, as one line.
alter user <YOUR_USERNAME> set rsa_public_key = '<PASTE_PUBLIC_KEY>';

use role transformer;
use warehouse ctgov_wh;

-- Landing table: one row per study per load, full API record kept as VARIANT.
create table if not exists ctgov_raw.ctgov.studies_raw (
    payload      variant,
    source_file  varchar,
    loaded_at    timestamp_ntz
);
