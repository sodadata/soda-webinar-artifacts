#!/usr/bin/env python3
"""Load a directory of CSVs into Postgres, overwriting existing tables.

Columns get realistic types (see TYPES); anything not listed defaults to TEXT.
The planted "failing" issues are encoded as values that are *valid for the type*
but break data-quality rules (out-of-range numbers, NULLs, stale/future dates,
bad categoricals, broken referential integrity) — so the messy set still loads
cleanly and stays visible to Soda checks. The clean set loads into the same
shapes. Tables are named after the CSV files; schema and credentials from ../.env.

    uv run --with "psycopg[binary]" load_to_postgres.py --source ./failing
"""
import csv, glob, os, sys
import psycopg

HERE = os.path.dirname(os.path.abspath(__file__))

# Realistic per-column types (matched by column name across all tables). The
# planted faults are deliberately kept castable to these types — e.g. age=-5 is
# a valid INTEGER that a Soda range check flags, not a load-time error. Columns
# absent here (ids like ORD-/SKU-, names, emails, categoricals) stay TEXT.
TYPES = {
    "customer_id": "INTEGER",
    "age": "INTEGER",
    "signup_date": "DATE",
    "is_active": "BOOLEAN",
    "order_date": "DATE",
    "ship_date": "DATE",
    "total_amount": "NUMERIC",
    "discount_pct": "INTEGER",
    "price": "NUMERIC",
    "cost": "NUMERIC",
    "stock_quantity": "INTEGER",
    "active": "BOOLEAN",
}


def env():
    keys = "DB_SCHEMA POSTGRES_HOST POSTGRES_PORT POSTGRES_USERNAME POSTGRES_DATABASE POSTGRES_PASSWORD".split()
    out = {}
    for line in open(os.path.join(HERE, "..", ".env")):
        k, _, v = line.strip().partition("=")
        if k in keys:
            out[k] = v.strip().strip("'\"")
    return out


def main():
    source = sys.argv[sys.argv.index("--source") + 1]
    e = env()
    schema = e["DB_SCHEMA"]
    csvs = sorted(glob.glob(os.path.join(os.path.abspath(source), "*.csv")))
    print(f"Loading {len(csvs)} table(s) from {source} into "
          f"{e['POSTGRES_HOST']}/{e['POSTGRES_DATABASE']} schema={schema}")

    with psycopg.connect(host=e["POSTGRES_HOST"], port=e.get("POSTGRES_PORT", "5432"),
                         user=e["POSTGRES_USERNAME"], password=e["POSTGRES_PASSWORD"],
                         dbname=e["POSTGRES_DATABASE"]) as conn, conn.cursor() as cur:
        cur.execute(f'CREATE SCHEMA IF NOT EXISTS "{schema}"')
        for path in csvs:
            table = os.path.splitext(os.path.basename(path))[0]
            header = next(csv.reader(open(path)))
            cols = ", ".join(f'"{c}" {TYPES.get(c, "TEXT")}' for c in header)
            qt = f'"{schema}"."{table}"'
            cur.execute(f"DROP TABLE IF EXISTS {qt} CASCADE")
            cur.execute(f"CREATE TABLE {qt} ({cols})")
            with open(path, "rb") as f, cur.copy(
                    f"COPY {qt} FROM STDIN WITH (FORMAT csv, HEADER true)") as cp:
                cp.write(f.read())
            print(f"  loaded {table}")
        conn.commit()
    print("Done.")


if __name__ == "__main__":
    main()
