"""
Build the PopBeauty database with the enforced schema, then check data integrity.

Reads the raw synthetic data (data/source_popbeauty.db), creates a new database from
sql/schema.sql with primary keys, foreign keys, unique keys and value checks, loads
every table in dependency order, and fails loudly if any row breaks a rule.

Usage:
  python src/build_db.py                 # writes data/popbeauty.db
"""
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "data" / "source_popbeauty.db"
TARGET = ROOT / "data" / "popbeauty.db"
SCHEMA = ROOT / "sql" / "schema.sql"

# Parents before children, so foreign keys can be checked as rows arrive
LOAD_ORDER = ["brands", "categories", "products", "stores", "warehouses",
              "store_inventory", "warehouse_inventory", "shipments", "sales"]


def build(source: Path = SOURCE, target: Path = TARGET) -> dict:
    target.unlink(missing_ok=True)
    src = sqlite3.connect(source)
    dst = sqlite3.connect(target)
    dst.executescript(SCHEMA.read_text())
    dst.execute("PRAGMA foreign_keys = ON")

    counts = {}
    for table in LOAD_ORDER:
        cols = [r[1] for r in dst.execute(f"PRAGMA table_info({table})")]
        rows = src.execute(f"SELECT {', '.join(cols)} FROM {table}").fetchall()
        placeholders = ", ".join("?" for _ in cols)
        try:
            dst.executemany(f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({placeholders})", rows)
        except sqlite3.IntegrityError as exc:
            dst.close()
            raise SystemExit(f"Integrity error while loading {table}: {exc}")
        counts[table] = len(rows)
    dst.commit()

    problems = dst.execute("PRAGMA foreign_key_check").fetchall()
    if problems:
        raise SystemExit(f"{len(problems)} foreign key violations, first: {problems[0]}")
    dst.close()
    return counts


if __name__ == "__main__":
    counts = build()
    for table, n in counts.items():
        print(f"{table:<20} {n:>6} rows")
    print(f"Built {TARGET.relative_to(ROOT)}: all keys and checks passed.")
    sys.exit(0)
