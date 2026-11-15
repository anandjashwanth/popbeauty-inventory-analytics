"""
Run every analytical query in sql/analysis_queries.sql against the built database.

Usage:
  python src/run_queries.py              # prints the row count for each query
  python src/run_queries.py --show 21    # prints the result of query 21
"""
import argparse
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "popbeauty.db"
QUERIES = ROOT / "sql" / "analysis_queries.sql"


def load_queries(path: Path = QUERIES) -> list[tuple[str, str]]:
    """Split the file on '-- Query NN: title' headers into (title, sql) pairs."""
    parts = re.split(r"^-- (Query \d+: .*)$", path.read_text(), flags=re.M)
    return [(parts[i].strip(), parts[i + 1].strip().rstrip(";")) for i in range(1, len(parts), 2)]


def run_all(db: Path = DB) -> list[tuple[str, int]]:
    con = sqlite3.connect(db)
    return [(title, len(con.execute(sql).fetchall())) for title, sql in load_queries()]


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--show", type=int, help="print the result of one query by number")
    a = p.parse_args()
    if a.show:
        title, sql = load_queries()[a.show - 1]
        con = sqlite3.connect(DB)
        cur = con.execute(sql)
        print(title)
        print(" | ".join(d[0] for d in cur.description))
        for row in cur.fetchall():
            print(" | ".join(str(v) for v in row))
    else:
        for title, n in run_all():
            print(f"{n:>6} rows  {title}")
