"""
Weekly demand forecasting by product category, with an honest backtest.

Compares four simple forecasting methods with rolling-origin backtesting
(each week is forecast using only the weeks before it), picks the most accurate
method per category, then turns the forecast into weeks of stock cover.

Usage:
  python src/build_db.py       # build the database first
  python src/forecast.py       # prints the backtest and writes output/forecast_*.csv
"""
import sqlite3
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "popbeauty.db"
OUT = ROOT / "output"
BACKTEST_WEEKS = 12
HORIZON = 4  # weeks ahead in the final forecast


def weekly_sales(con) -> pd.DataFrame:
    """Units sold per category per complete week (Monday to Sunday)."""
    df = pd.read_sql(
        """SELECT s.sale_date, c.category_name, s.quantity_sold
           FROM sales s
           JOIN products p ON p.product_id = s.product_id
           JOIN categories c ON c.category_id = p.category_id""",
        con, parse_dates=["sale_date"])
    weekly = (df.set_index("sale_date").groupby("category_name")["quantity_sold"]
                .resample("W-SUN").sum().unstack(0).fillna(0))
    last_day = df["sale_date"].max()
    if last_day.dayofweek != 6:          # drop the final, incomplete week
        weekly = weekly.iloc[:-1]
    return weekly


# ---- forecasting methods: each takes the history and returns a one-step forecast ----
def naive(h):
    return h[-1]


def moving_average(h, k=4):
    return h[-k:].mean()


def exp_smoothing(h, alpha=0.3):
    level = h[0]
    for x in h[1:]:
        level = alpha * x + (1 - alpha) * level
    return level


def trend(h, k=12):
    y = h[-k:]
    x = np.arange(len(y))
    slope, intercept = np.polyfit(x, y, 1)
    return max(intercept + slope * len(y), 0)


METHODS = {"naive": naive, "moving_average_4w": moving_average,
           "exp_smoothing": exp_smoothing, "linear_trend_12w": trend}


def wape(actual, forecast):
    """Weighted absolute percentage error: total absolute error / total actual."""
    actual, forecast = np.asarray(actual), np.asarray(forecast)
    return np.abs(actual - forecast).sum() / actual.sum()


def backtest(series: np.ndarray, weeks: int = BACKTEST_WEEKS) -> dict:
    """Rolling-origin backtest: forecast each of the last `weeks` weeks from its past only."""
    results = {}
    for name, fn in METHODS.items():
        preds = [fn(series[:t]) for t in range(len(series) - weeks, len(series))]
        results[name] = wape(series[-weeks:], preds)
    return results


def run(db: Path = DB):
    con = sqlite3.connect(db)
    weekly = weekly_sales(con)
    rows = []
    for cat in weekly.columns:
        scores = backtest(weekly[cat].to_numpy(dtype=float))
        best = min(scores, key=scores.get)
        rows.append({"category": cat, **{k: round(v, 3) for k, v in scores.items()},
                     "best_method": best,
                     "improvement_vs_naive": round(1 - scores[best] / scores["naive"], 3),
                     "weekly_forecast": round(METHODS[best](weekly[cat].to_numpy(dtype=float)), 1)})
    bt = pd.DataFrame(rows).set_index("category")

    stock = pd.read_sql(
        """SELECT c.category_name AS category, SUM(si.quantity) AS store_stock
           FROM store_inventory si
           JOIN products p ON p.product_id = si.product_id
           JOIN categories c ON c.category_id = p.category_id
           GROUP BY c.category_name""", con).set_index("category")
    cover = bt[["weekly_forecast"]].join(stock)
    cover["forecast_next_4_weeks"] = cover["weekly_forecast"] * HORIZON
    cover["weeks_of_cover"] = (cover["store_stock"] / cover["weekly_forecast"]).round(1)

    OUT.mkdir(exist_ok=True)
    bt.to_csv(OUT / "forecast_backtest.csv")
    cover.to_csv(OUT / "forecast_cover.csv")
    return weekly, bt, cover


if __name__ == "__main__":
    weekly, bt, cover = run()
    print(f"{len(weekly)} complete weeks, {weekly.index.min().date()} to {weekly.index.max().date()}")
    print(f"\nBacktest WAPE over the last {BACKTEST_WEEKS} weeks (lower is better):")
    print(bt.to_string())
    print("\nWeeks of stock cover at forecast demand:")
    print(cover.to_string())
