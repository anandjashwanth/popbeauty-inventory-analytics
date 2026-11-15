# PopBeauty: Retail Inventory Analytics (SQL, data modelling, Power BI)

[![CI](https://github.com/anandjashwanth/popbeauty-inventory-analytics/actions/workflows/ci.yml/badge.svg)](https://github.com/anandjashwanth/popbeauty-inventory-analytics/actions/workflows/ci.yml)

**Diagnosing a £67K+ inventory imbalance across a 13-store UK beauty retailer with a relational database, 26 SQL queries and a Power BI dashboard.**

> This is an academic group project (Warwick Business School, MSc Business Analytics) built on **synthetic data** for a **fictional** retailer, "PopBeauty". It is shared as a portfolio piece, not as real company data.

## My contribution
This was a six-person team project. My role covered the core technical build and analysis: I designed and built the SQLite database, wrote the SQL queries behind the insights below, carried out the data analysis, wrote the report and co-presented the findings. The Power BI dashboards are my own build.

## The problem
PopBeauty's 13 stores were not receiving stock in proportion to demand. Smaller stores built up stock they could not sell, while high-footfall stores ran short. **The stock already existed inside the network**, so this was an allocation and process problem, not a supply shortage, and it caused stockouts and write-offs at the same time.

The question: *where is the money trapped, and why?*

## Data model
Nine tables in third normal form (3NF): Brands, Categories, Products, Stores, Warehouses, Store_Inventory, Warehouse_Inventory, Shipments and Sales.

![ER diagram](images/er-diagram.png)

The schema in [`sql/schema.sql`](sql/schema.sql) **enforces** the model rather than just describing it:
- primary keys on every table and foreign keys on every relationship;
- unique keys, for example one inventory row per store and product;
- value checks, for example no negative stock and discounts between 0 and 1;
- indexes on the most-joined columns.

[`src/build_db.py`](src/build_db.py) loads the raw synthetic data into this schema in dependency order and fails loudly if any row breaks a rule. All 4,843 rows pass.

## Key insights (all from SQL)
1. **Misplacement, not shortage.** The London Flagship converted **43%** of its stock into sales against **9 to 12%** at boutiques, while holding the *fewest* units.
2. **Premium products in the wrong stores.** Around 280 to 300 units of Dyson Airwrap and FOREO LUNA sat in boutiques selling 0 to 1 units, while the Flagship held 2 to 5 units at critical level. Beauty Tools carry the highest gross margin (59%), so this was a margin problem, not just a revenue one.
3. **£67K+ of expiry risk.** Short-life skincare in Birmingham and Coventry was nearing expiry unsold, while the *same products* were critically short in Edinburgh and Glasgow.
4. **A 394-day "ghost shipment".** 25 shipments were stuck "In Transit", the oldest for 394 days from a warehouse 10 miles away. Because the system treated them as pending, it suppressed new orders and kept Manchester and Liverpool empty.
5. **One reorder rule for every store.** Identical reorder thresholds were applied to stores whose sales rates differ by 10 times, overstocking slow stores and starving fast ones.
6. **Discounting as a symptom.** Repeated 17 to 19% discounts at slow stores failed to clear stock; the same products sold at full price, in 6 to 7 times the volume, at the Flagship.

## Recommendation
**£67K+ recoverable with £0 extra spend**, using stock already in the network: redistribute premium tools and expiring skincare to where demand is, write off and replace the ghost shipments, stop ineffective discounting, and set reorder levels from each store's sales rate.

## Run it yourself
```bash
pip install -r requirements-dev.txt
python src/build_db.py                 # builds data/popbeauty.db with enforced keys and checks
python src/run_queries.py              # runs all 26 analysis queries and prints row counts
python src/run_queries.py --show 21    # shows one result, e.g. the stuck shipments
pytest -q                              # data integrity and query tests
```

**Continuous integration:** on every push, GitHub Actions lints the code, rebuilds the database, runs all 26 queries and runs the tests. The tests check that every table loads, no foreign key is broken, bad data (an unknown store, a duplicate inventory row, negative stock) is rejected, every query returns results, and the headline finding still holds.

## Repository contents
| Path | What it is |
|---|---|
| `sql/schema.sql` | Database schema with primary, foreign and unique keys and value checks |
| `sql/analysis_queries.sql` | All 26 analysis queries, numbered and labelled by question |
| `src/build_db.py` | Builds the database from the raw synthetic data and checks integrity |
| `src/run_queries.py` | Runs every query, or shows one result |
| `tests/test_database.py` | Data integrity and query tests |
| `notebooks/popbeauty_sql_analysis.ipynb` | The full analysis with findings and charts |
| `data/source_popbeauty.db` | Raw synthetic data |
| `images/er-diagram.png` | Entity relationship diagram |
| [`Popbeauty dashboard.pdf`](Popbeauty%20dashboard.pdf) | Power BI dashboard |
| [`IB9HP0_Group_12_Code.pdf`](IB9HP0_Group_12_Code.pdf) | Original submitted notebook as PDF |

## Skills shown
SQL (joins, CTEs, aggregation, CASE logic, date functions) · relational data modelling (ER design, 3NF, keys and constraints) · data integrity testing (pytest) · CI (GitHub Actions) · Python · Power BI · root-cause analysis and business communication.
