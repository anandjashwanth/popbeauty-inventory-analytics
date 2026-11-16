import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "src"))
import build_db  # noqa: E402
import forecast  # noqa: E402


def test_wape():
    assert forecast.wape([10, 10], [8, 12]) == 0.2


def test_backtest_uses_only_past_data():
    """A series that jumps in the final week cannot be predicted by any method."""
    series = np.array([10.0] * 30 + [100.0])
    scores = forecast.backtest(series, weeks=1)
    assert all(score > 0.8 for score in scores.values())


def test_methods_are_exact_on_flat_series():
    series = np.full(30, 7.0)
    assert all(abs(fn(series) - 7.0) < 1e-9 for fn in forecast.METHODS.values())


def test_full_run(tmp_path):
    db = tmp_path / "popbeauty.db"
    build_db.build(target=db)
    weekly, bt, cover = forecast.run(db)
    assert len(bt) == 6
    assert (bt["improvement_vs_naive"] >= 0).all()   # best method never worse than naive
    assert weekly.index.max().dayofweek == 6         # only complete weeks are used
