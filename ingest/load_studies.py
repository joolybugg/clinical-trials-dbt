"""Pull studies from the ClinicalTrials.gov v2 API and land them in Snowflake.

Each study is written as one line of newline-delimited JSON, staged to the
table stage of CTGOV_RAW.CTGOV.STUDIES_RAW with PUT, and loaded with COPY INTO
so the full record lands as a VARIANT. All parsing happens downstream in dbt.

Usage:
    python ingest/load_studies.py --condition "diabetes" --max-pages 5
"""

from __future__ import annotations

import argparse
import gzip
import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import requests
import snowflake.connector
from dotenv import load_dotenv

API_URL = "https://clinicaltrials.gov/api/v2/studies"
RAW_TABLE = "CTGOV_RAW.CTGOV.STUDIES_RAW"
TABLE_STAGE = "@CTGOV_RAW.CTGOV.%STUDIES_RAW"  # every table has its own internal stage


def fetch_studies(condition: str, max_pages: int, page_size: int = 1000):
    """Yield study records page by page, following nextPageToken."""
    params = {
        "query.cond": condition,
        "filter.overallStatus": "RECRUITING,ACTIVE_NOT_RECRUITING,COMPLETED,NOT_YET_RECRUITING",
        "pageSize": page_size,
        "format": "json",
    }
    session = requests.Session()
    for page in range(1, max_pages + 1):
        resp = session.get(API_URL, params=params, timeout=60)
        resp.raise_for_status()
        body = resp.json()
        studies = body.get("studies", [])
        print(f"page {page}: {len(studies)} studies")
        yield from studies
        token = body.get("nextPageToken")
        if not token:
            break
        params["pageToken"] = token


def write_ndjson(studies, out_dir: Path) -> tuple[Path, int]:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = out_dir / f"studies_{stamp}.json.gz"
    count = 0
    with gzip.open(path, "wt", encoding="utf-8") as fh:
        for study in studies:
            fh.write(json.dumps(study) + "\n")
            count += 1
    return path, count


def load_to_snowflake(path: Path) -> None:
    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        authenticator="SNOWFLAKE_JWT",
        private_key_file=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
        role=os.getenv("SNOWFLAKE_ROLE", "TRANSFORMER"),
        warehouse=os.getenv("SNOWFLAKE_WAREHOUSE", "CTGOV_WH"),
    )
    try:
        cur = conn.cursor()
        cur.execute(f"PUT file://{path.as_posix()} {TABLE_STAGE} AUTO_COMPRESS=FALSE OVERWRITE=TRUE")
        cur.execute(
            f"""
            COPY INTO {RAW_TABLE} (payload, source_file, loaded_at)
            FROM (
                SELECT $1, METADATA$FILENAME, CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
                FROM {TABLE_STAGE}
            )
            FILES = ('{path.name}')
            FILE_FORMAT = (TYPE = 'JSON' COMPRESSION = 'GZIP')
            """
        )
        for row in cur.fetchall():
            print("copy result:", row)
    finally:
        conn.close()


def main() -> None:
    load_dotenv()
    parser = argparse.ArgumentParser()
    parser.add_argument("--condition", default="diabetes")
    parser.add_argument("--max-pages", type=int, default=5)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        path, count = write_ndjson(fetch_studies(args.condition, args.max_pages), Path(tmp))
        print(f"wrote {count} studies to {path.name}")
        if count:
            load_to_snowflake(path)


if __name__ == "__main__":
    main()
