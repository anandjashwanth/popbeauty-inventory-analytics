# Metric definitions

Every number in the analysis comes from one of these definitions. Each one states exactly what the SQL counts, so two people computing it get the same answer, and lists the known limitations found while documenting it.

| Metric | Exact definition (as in `sql/analysis_queries.sql`) | Grain | Edge cases and known limitations |
|---|---|---|---|
| **Sell-through ratio** (Q05) | Units sold over the whole data period (Jan 2025 to Mar 2026) ÷ units currently in stock | Store | A store with zero stock returns NULL rather than infinity. Compares a 15-month sales total with a single stock snapshot, so it ranks stores well but is not a true period sell-through rate. |
| **Below minimum** (Q06) | `quantity < min_stock_level` | Store × product | Equal to the minimum is not counted. |
| **Overstock** (Q07) | `quantity ÷ reorder_level > 3`, top 30 shown | Store × product | Rows with a reorder level of 0 are excluded to avoid division by zero. The 3× threshold is a judgement call, stated so it can be challenged. |
| **Expiry risk** (Q08) | Expiry within 0 to 180 days of 26 March 2026, with more than 30 units on hand | Store × product | The fixed analysis date makes results reproducible. Items already expired are excluded. |
| **Units at risk of expiry** (Q17) | Units on hand − (2025 units sold ÷ 12 × months to expiry), floored at 0; months = days ÷ 30 | Store × product (Skincare, more than 20 units) | A product launched mid-2025 has its monthly sales understated, so its risk is overstated. |
| **Write-off value at risk** (Q17) | Units at risk × **retail** unit price | Store × product | Uses retail price, not cost price, so it overstates the cash actually lost. Restating at cost would give a smaller, more conservative figure. |
| **Stuck shipment** (Q21) | Status "In Transit" or "Partially Received" with no received date; days counted to 26 March 2026 | Shipment | Scoped to the North Warehouse and the Manchester and Liverpool stores, where the problem was found. |
| **Reorder cover** (Q22) | Average reorder level ÷ average 2025 monthly sales per product | Store | Products with no 2025 sales count as 0 in the average, which lowers sales and raises cover. |
| **Gross margin** (Q11) | Σ (list price − cost price) × units ÷ Σ actual sales revenue | Category or store | Profit uses list price while revenue is after discounts, so margin is overstated where discounting is heavy. |
| **Forecast error, WAPE** (`src/forecast.py`) | Σ abs(actual − forecast) ÷ Σ actual units, over a 12-week rolling backtest | Category × week | Chosen over MAPE because MAPE breaks on weeks with zero sales. |
