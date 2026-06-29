# PopBeauty — Retail Inventory Analytics (SQL + Power BI)

**Diagnosing a £67K+ inventory imbalance across a 13-store UK beauty retail network — using relational database design, SQL, and Power BI.**

> **Note:** This is an academic group project (Warwick Business School, MSc Business Analytics, module IB9HP0) built on **synthetic data** for a **fictional** retailer, "PopBeauty." It is shared as a portfolio piece to demonstrate technical and analytical work, not as real company data.

---

## My contribution

This was a six-person team project. **My role covered the core technical build and analysis:** I designed and built the SQLite database, wrote the SQL queries that produced every insight below, carried out the data analysis, authored the written report, and co-presented the findings. The dashboards in this repo are my own build in Power BI.

---

## The problem

PopBeauty's 13 stores were not receiving inventory in proportion to where demand actually was. Smaller stores accumulated stock they couldn't sell, while high-footfall stores ran short of the products customers wanted. Critically, **this was not a supply shortage — the stock already existed inside the network.** It was an *allocation and process* problem, producing both stockout costs and excess-holding / write-off costs at the same time.

The analysis set out to answer one question: *where is the money trapped, and why?*

## What I built

- A **relational database** (9 entities — Stores, Warehouses, Brands, Categories, Products, Store_Inventory, Warehouse_Inventory, Sales, Shipments), normalised to **Third Normal Form (3NF)**, implemented in **SQLite**.
- **22 analytical SQL queries** (joins, aggregations, ratio and date logic) diagnosing the imbalance across cost, expiry, fulfilment and reorder behaviour.
- A multi-page **Power BI dashboard** translating the findings into a clear business narrative for decision-makers.

📄 **[View the full SQL queries (PDF)](IB9HP0_Group_12_Code.pdf)**

## Key insights (all surfaced from SQL)

1. **Misplacement, not shortage.** The London Flagship converted **43%** of its stock into sales versus **9–12%** at boutiques — while holding the *fewest* units. The highest-demand store was understocked; the slowest stores were overstocked.
2. **Premium product misallocation.** ~280–300 units of high-margin Dyson Airwrap / FOREO LUNA 4 sat in boutiques (selling 0–1 units), while the Flagship — the proven market — held just 2–5 units at CRITICAL status. Beauty Tools carry the network's **highest gross margin (59%)**, so this was a margin problem, not just a revenue one.
3. **Expiry risk worth £67K+.** Short-life skincare in Birmingham and Coventry was approaching expiry unsold — while the *same SKUs* were at critical shortage in Edinburgh and Glasgow. Redistribution (not procurement) was the fix.
4. **A 394-day "ghost shipment."** Root-cause analysis of the Shipments table found 25 shipments stuck "In Transit" — the oldest open for **394 days** for a warehouse 10 miles from the store. Because the system treated them as pending, it *suppressed* new replenishment orders, keeping Manchester and Liverpool empty while a full warehouse sat nearby.
5. **The uniform-policy fallacy.** Identical reorder thresholds were applied across stores whose sell-rates varied by **10×**, systematically over-stocking slow stores and starving fast ones. A velocity-based reorder formula was proposed, tiered by store type.
6. **Discounting as a symptom.** Repeated 17–19% discounts at slow stores failed to clear stock, because the demand wasn't there — the same products sold full-price, in 6–7× volumes, at the Flagship.

## Recommendation

**£67K+ recoverable with £0 extra spend** — every fix used stock already in the network: redistribute premium tools and expiring skincare to where demand exists, write off and replace the 25 ghost shipments, halt ineffective discounting, and recalibrate reorder levels to store-level velocity.

## Tech & skills demonstrated

`SQLite` · `SQL` (joins, aggregation, window/ratio logic, date functions) · **relational data modelling (ER design, 3NF normalisation)** · `Power BI` (dashboards, data visualisation) · `Python` (synthetic data generation, analysis) · business-insight communication and root-cause analysis.

## Repo contents

```
README.md                  — this case study
popbeauty_sql_queries.pdf  — full SQL queries (schema + analytical queries)
/dashboards/               — Power BI dashboard screenshots
er-diagram.png             — entity-relationship model
/files/                    — (optional) source .pbix / .db
```
