import sqlite3
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "src"))
import build_db  # noqa: E402
import run_queries  # noqa: E402


@pytest.fixture(scope="session")
def db(tmp_path_factory):
    path = tmp_path_factory.mktemp("db") / "popbeauty.db"
    build_db.build(target=path)
    con = sqlite3.connect(path)
    con.execute("PRAGMA foreign_keys = ON")
    yield con
    con.close()


def test_all_tables_loaded(db):
    expected = {"stores": 13, "warehouses": 6, "brands": 65, "categories": 6, "products": 180,
                "store_inventory": 1038, "warehouse_inventory": 1000, "shipments": 1020, "sales": 1515}
    for table, n in expected.items():
        assert db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] == n


def test_no_foreign_key_violations(db):
    assert db.execute("PRAGMA foreign_key_check").fetchall() == []


def test_sale_for_unknown_store_is_rejected(db):
    with pytest.raises(sqlite3.IntegrityError):
        db.execute("INSERT INTO sales VALUES ('TEST1', 'NO_SUCH_STORE', 'P001', '2025-01-01', 1, 10, 10, 0)")


def test_duplicate_store_product_is_rejected(db):
    sid, pid = db.execute("SELECT store_id, product_id FROM store_inventory LIMIT 1").fetchone()
    with pytest.raises(sqlite3.IntegrityError):
        db.execute("INSERT INTO store_inventory VALUES ('TEST2', ?, ?, 1, 1, 1, NULL, NULL)", (sid, pid))


def test_negative_stock_is_rejected(db):
    with pytest.raises(sqlite3.IntegrityError):
        db.execute("UPDATE store_inventory SET quantity = -1 WHERE rowid = 1")


def test_every_analysis_query_runs(tmp_path):
    path = tmp_path / "popbeauty.db"
    build_db.build(target=path)
    results = run_queries.run_all(path)
    assert len(results) == 26
    assert all(n > 0 for _, n in results)


def test_flagship_leads_sell_through(db):
    """Headline finding: London Flagship converts the most stock into sales."""
    title, sql = run_queries.load_queries()[4]
    assert "Sell-through" in title
    rows = db.execute(sql).fetchall()
    assert "London" in rows[0][0]
