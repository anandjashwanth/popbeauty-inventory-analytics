-- PopBeauty retail inventory analysis: all analytical queries (SQLite)
-- Run them all with:  python run_queries.py

-- Query 01: A.1. How many stores do we have, and what types?
SELECT store_id, store_name, city, region, store_size_category
FROM stores
ORDER BY store_size_category, store_name;

-- Query 02: A.2. What product categories do we carry?
SELECT c.category_name,
       COUNT(DISTINCT p.product_id) as num_products,
       ROUND(AVG(p.unit_price), 2) as avg_price,
       ROUND(MIN(p.unit_price), 2) as min_price,
       ROUND(MAX(p.unit_price), 2) as max_price
FROM products p
JOIN categories c ON p.category_id = c.category_id
GROUP BY c.category_name
ORDER BY avg_price DESC;

-- Query 03: A.3. How much total stock does each store currently hold?
SELECT s.store_name, s.store_size_category, s.region,
       COUNT(DISTINCT si.product_id) as distinct_skus,
       SUM(si.quantity) as total_units_on_hand,
       ROUND(AVG(si.quantity), 1) as avg_units_per_sku
FROM store_inventory si
JOIN stores s ON si.store_id = s.store_id
GROUP BY s.store_id, s.store_name, s.store_size_category, s.region
ORDER BY total_units_on_hand DESC;

-- Query 04: B.1. Total Sales by Store (Units and Revenue)
SELECT s.store_name, s.store_size_category,
       COUNT(sa.sale_id) as num_transactions,
       SUM(sa.quantity_sold) as total_units_sold,
       ROUND(SUM(sa.total_amount), 2) as total_revenue,
       ROUND(AVG(sa.quantity_sold), 2) as avg_units_per_transaction
FROM sales sa
JOIN stores s ON sa.store_id = s.store_id
GROUP BY s.store_id, s.store_name, s.store_size_category
ORDER BY total_revenue DESC;

-- Query 05: B.2. Sales Velocity [Sell-through Ratio]
SELECT s.store_name, s.store_size_category,
       inv.total_stock,
       COALESCE(sal.total_sold, 0) as total_units_sold,
       ROUND(CAST(COALESCE(sal.total_sold,0) AS FLOAT) / NULLIF(inv.total_stock,0), 3) as sell_through_ratio
FROM stores s
LEFT JOIN (
    SELECT store_id, SUM(quantity) as total_stock
    FROM store_inventory
    GROUP BY store_id
) inv ON s.store_id = inv.store_id
LEFT JOIN (
    SELECT store_id, SUM(quantity_sold) as total_sold
    FROM sales
    GROUP BY store_id
) sal ON s.store_id = sal.store_id
ORDER BY sell_through_ratio DESC;

-- Query 06: C.1. Stores where quantity has dropped BELOW their minimum stock level
SELECT s.store_name, s.store_size_category,
       si.product_id, p.product_name, c.category_name,
       si.quantity, si.min_stock_level, si.reorder_level,
       si.quantity - si.min_stock_level as units_below_minimum
FROM store_inventory si
JOIN stores s ON si.store_id = s.store_id
JOIN products p ON si.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
WHERE si.quantity < si.min_stock_level
ORDER BY units_below_minimum ASC, s.store_name;

-- Query 07: C.2. Stores where quantity is MORE THAN 3× their reorder level (overstock)
SELECT s.store_name, s.store_size_category,
       si.product_id, p.product_name, c.category_name,
       si.quantity, si.reorder_level,
       ROUND(CAST(si.quantity AS FLOAT) / si.reorder_level, 1) as stock_to_reorder_ratio
FROM store_inventory si
JOIN stores s ON si.store_id = s.store_id
JOIN products p ON si.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
WHERE si.reorder_level > 0 AND CAST(si.quantity AS FLOAT) / si.reorder_level > 3.0
ORDER BY stock_to_reorder_ratio DESC
LIMIT 30;

-- Query 08: C.3. Expiry Risk (Products Expiring Within 6 Months with HIGH Stock)
SELECT s.store_name, s.store_size_category, s.region,
       p.product_name, c.category_name,
       p.shelf_life_months,
       si.quantity,
       si.expiry_date,
       CAST(julianday(si.expiry_date) - julianday('2026-03-26') AS INTEGER) as days_to_expiry
FROM store_inventory si
JOIN stores s ON si.store_id = s.store_id
JOIN products p ON si.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
WHERE si.expiry_date IS NOT NULL
  AND julianday(si.expiry_date) - julianday('2026-03-26') BETWEEN 0 AND 180
  AND si.quantity > 30
ORDER BY days_to_expiry ASC, si.quantity DESC;

-- Query 09: D.1. Revenue by Category and Store Size
SELECT s.store_size_category, c.category_name,
       SUM(sa.quantity_sold) as total_units,
       ROUND(SUM(sa.total_amount), 2) as total_revenue,
       COUNT(DISTINCT sa.store_id) as num_stores
FROM sales sa
JOIN stores s ON sa.store_id = s.store_id
JOIN products p ON sa.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
GROUP BY s.store_size_category, c.category_name
ORDER BY s.store_size_category, total_revenue DESC;

-- Query 10: D.2. Beauty Tools and Fragrance: Stock vs Sales by Store
SELECT s.store_name, s.store_size_category,
       c.category_name,
       SUM(si.quantity) as units_in_stock,
       COALESCE(SUM(sa.quantity_sold), 0) as units_sold,
       ROUND(COALESCE(SUM(sa.total_amount), 0), 2) as revenue,
       ROUND(
           CAST(COALESCE(SUM(sa.quantity_sold),0) AS FLOAT) / NULLIF(SUM(si.quantity),0)
       , 3) as sell_through
FROM store_inventory si
JOIN stores s ON si.store_id = s.store_id
JOIN products p ON si.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
LEFT JOIN sales sa ON si.store_id = sa.store_id AND si.product_id = sa.product_id
WHERE c.category_name IN ('Beauty Tools', 'Fragrance')
GROUP BY s.store_id, s.store_name, s.store_size_category, c.category_name
ORDER BY c.category_name, sell_through DESC;

-- Query 11: D.3. Gross Profit by Category and Stores
SELECT
    c.category_id,
    c.category_name,
    SUM(s.quantity_sold) AS total_units,
    SUM(s.total_amount) AS total_revenue,
    SUM((p.unit_price - p.cost_price) * s.quantity_sold) AS gross_profit,
    ROUND(
        SUM((p.unit_price - p.cost_price) * s.quantity_sold) * 1.0 /
        NULLIF(SUM(s.total_amount), 0),
        4
    ) AS profit_margin
FROM sales s
JOIN products p
    ON s.product_id = p.product_id
JOIN categories c
    ON p.category_id = c.category_id
GROUP BY c.category_id, c.category_name
ORDER BY gross_profit DESC;

-- Query 12: D.3. Gross Profit by Category and Stores (part 2)
SELECT
    s.store_id,
    st.store_name,
    SUM(s.quantity_sold) AS total_units,
    SUM(s.total_amount) AS total_revenue,
    SUM((p.unit_price - p.cost_price) * s.quantity_sold) AS gross_profit,
    ROUND(
        SUM((p.unit_price - p.cost_price) * s.quantity_sold) * 1.0 /
        NULLIF(SUM(s.total_amount), 0),
        4
    ) AS profit_margin
FROM sales s
JOIN products p
    ON s.product_id = p.product_id
JOIN stores st
    ON s.store_id = st.store_id
GROUP BY s.store_id, st.store_name
ORDER BY gross_profit DESC;

-- Query 13: D.3. Gross Profit by Category and Stores (part 3)
SELECT
    st.store_size_category,
    c.category_name,
    SUM(
        s.total_amount - (p.cost_price * s.quantity_sold)
    ) AS gross_profit
FROM sales s
JOIN products p
    ON s.product_id = p.product_id
JOIN stores st
    ON s.store_id = st.store_id
JOIN categories c
    ON p.category_id = c.category_id
GROUP BY st.store_size_category, c.category_name;

-- Query 14: E.1. Dyson Airwrap and FOREO LUNA
SELECT s.store_name, s.store_size_category,
       p.product_name, p.unit_price,
       si.quantity as stock_on_hand,
       si.reorder_level, si.min_stock_level,
       CASE WHEN si.quantity < si.min_stock_level THEN 'CRITICAL'
            WHEN si.quantity < si.reorder_level THEN 'LOW'
            WHEN si.quantity > si.reorder_level * 3 THEN 'EXCESS'
            ELSE 'OK' END as stock_status
FROM store_inventory si
JOIN stores s ON si.store_id = s.store_id
JOIN products p ON si.product_id = p.product_id
WHERE si.product_id IN ('PRD0075','PRD0077','PRD0157','PRD0159')
ORDER BY p.product_name, si.quantity DESC;

-- Query 15: E.2. Monthly Sales Velocity for Dyson Airwrap and FOREO LUNA - Who Actually Buys Them?
SELECT s.store_name, s.store_size_category,
       p.product_name,
       strftime('%Y-%m', sa.sale_date) as year_month,
       SUM(sa.quantity_sold) as units_sold
FROM sales sa
JOIN stores s ON sa.store_id = s.store_id
JOIN products p ON sa.product_id = p.product_id
WHERE sa.product_id IN ('PRD0075','PRD0077','PRD0157','PRD0159')
GROUP BY s.store_id, p.product_id, year_month
ORDER BY p.product_name, s.store_name, year_month;

-- Query 16: F1. Which stores hold the most short-shelf-life Skincare products?
SELECT s.store_name, s.store_size_category, s.region,
       COUNT(DISTINCT si.product_id) as short_life_skus,
       SUM(si.quantity) as total_units,
       MIN(CAST(julianday(si.expiry_date) - julianday('2026-03-26') AS INTEGER)) as min_days_to_expiry,
       AVG(CAST(julianday(si.expiry_date) - julianday('2026-03-26') AS INTEGER)) as avg_days_to_expiry
FROM store_inventory si
JOIN stores s ON si.store_id = s.store_id
JOIN products p ON si.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
WHERE p.shelf_life_months <= 16
  AND c.category_name = 'Skincare'
  AND si.expiry_date IS NOT NULL
GROUP BY s.store_id, s.store_name, s.store_size_category, s.region
ORDER BY avg_days_to_expiry ASC;

-- Query 17: F.2. Calculate units at risk of expiring before they can be sold
WITH monthly_sales AS (
    SELECT sa.store_id, sa.product_id,
           CAST(SUM(sa.quantity_sold) AS FLOAT) / 12.0 as avg_monthly_sales
    FROM sales sa
    WHERE strftime('%Y', sa.sale_date) = '2025'
    GROUP BY sa.store_id, sa.product_id
),
inventory_with_expiry AS (
    SELECT si.store_id, si.product_id, si.quantity, si.expiry_date,
           CAST(julianday(si.expiry_date) - julianday('2026-03-26') AS FLOAT) / 30.0 as months_to_expiry
    FROM store_inventory si
    WHERE si.expiry_date IS NOT NULL
      AND julianday(si.expiry_date) - julianday('2026-03-26') BETWEEN 0 AND 180
)
SELECT s.store_name, s.region, p.product_name, p.shelf_life_months,
       ie.quantity as stock_on_hand,
       ROUND(COALESCE(ms.avg_monthly_sales, 0), 1) as avg_monthly_sales,
       ROUND(ie.months_to_expiry, 1) as months_to_expiry,
       ie.expiry_date,
       MAX(0, CAST(ie.quantity - (COALESCE(ms.avg_monthly_sales,0) * ie.months_to_expiry) AS INTEGER)) as estimated_units_expiring,
       ROUND(p.unit_price * MAX(0, ie.quantity - (COALESCE(ms.avg_monthly_sales,0) * ie.months_to_expiry)), 2) as estimated_write_off_value
FROM inventory_with_expiry ie
JOIN stores s ON ie.store_id = s.store_id
JOIN products p ON ie.product_id = p.product_id
LEFT JOIN monthly_sales ms ON ie.store_id = ms.store_id AND ie.product_id = ms.product_id
JOIN categories c ON p.category_id = c.category_id
WHERE c.category_name = 'Skincare'
  AND ie.quantity > 20
ORDER BY estimated_write_off_value DESC;

-- Query 18: F.3. Meanwhile, Scotland stores are undersupplied on the same products
SELECT s.store_name, s.region, p.product_name,
       si.quantity as stock_on_hand,
       si.min_stock_level, si.reorder_level,
       CASE WHEN si.quantity < si.min_stock_level THEN 'CRITICAL SHORTAGE'
            WHEN si.quantity < si.reorder_level THEN 'BELOW REORDER'
            ELSE 'OK' END as status
FROM store_inventory si
JOIN stores s ON si.store_id = s.store_id
JOIN products p ON si.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
WHERE s.store_id IN ('ST012','ST013')
  AND p.product_id IN ('PRD0137','PRD0139','PRD0052','PRD0145')
ORDER BY p.product_name, si.quantity ASC;

-- Query 19: G.1. Warehouse stock levels vs store shortages for core Makeup products
SELECT p.product_name, c.category_name,
       wh.warehouse_name, wh.location as wh_location,
       wi.quantity_on_hand as warehouse_stock,
       s.store_name, s.store_size_category,
       si.quantity as store_stock,
       si.reorder_level,
       CASE WHEN si.quantity < si.min_stock_level THEN 'CRITICAL'
            WHEN si.quantity < si.reorder_level THEN 'BELOW REORDER'
            ELSE 'OK' END as store_status
FROM store_inventory si
JOIN stores s ON si.store_id = s.store_id
JOIN products p ON si.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN warehouse_inventory wi ON wi.product_id = si.product_id
JOIN warehouses wh ON wi.warehouse_id = wh.warehouse_id
WHERE si.quantity < si.reorder_level
  AND wi.quantity_on_hand > 500
  AND wh.warehouse_id = 'WH002'
  AND s.store_id IN ('ST003','ST004')
ORDER BY wi.quantity_on_hand DESC, si.quantity ASC
LIMIT 20;

-- Query 20: G.2. Stock Redistribution Opportunity
SELECT
    st.store_id,
    st.store_name,
    si.product_id,
    p.product_name,
    si.quantity AS store_stock,
    si.reorder_level,
    si.min_stock_level,
    wi.warehouse_id,
    w.warehouse_name,
    wi.quantity_on_hand AS warehouse_stock,
    (si.reorder_level - si.quantity) AS shortage_units
FROM store_inventory si
JOIN stores st
    ON si.store_id = st.store_id
JOIN products p
    ON si.product_id = p.product_id
JOIN warehouse_inventory wi
    ON si.product_id = wi.product_id
JOIN warehouses w
    ON wi.warehouse_id = w.warehouse_id
WHERE si.quantity < si.reorder_level
  AND wi.quantity_on_hand > 0
ORDER BY shortage_units DESC, warehouse_stock DESC;

-- Query 21: G.3. Shipment Status (stuck shipments)
SELECT sh.shipment_id,
       wh.warehouse_name, s.store_name, s.store_size_category,
       p.product_name,
       sh.quantity,
       sh.shipment_date,
       sh.received_date,
       sh.shipment_status,
       CASE
           WHEN sh.received_date IS NULL
           THEN CAST(julianday('2026-03-26') - julianday(sh.shipment_date) AS INTEGER)
           ELSE NULL
       END as days_in_transit
FROM shipments sh
JOIN warehouses wh ON sh.warehouse_id = wh.warehouse_id
JOIN stores s ON sh.store_id = s.store_id
JOIN products p ON sh.product_id = p.product_id
WHERE sh.warehouse_id = 'WH002'
  AND sh.store_id IN ('ST003','ST004')
  AND sh.shipment_status IN ('In Transit','Partially Received')
ORDER BY days_in_transit DESC NULLS LAST;

-- Query 22: H.1. Compare reorder levels to actual monthly sales by store size
WITH monthly_velocity AS (
    SELECT sa.store_id, sa.product_id,
           CAST(SUM(sa.quantity_sold) AS FLOAT) / 12.0 as avg_monthly_sales
    FROM sales sa
    WHERE strftime('%Y', sa.sale_date) = '2025'
    GROUP BY sa.store_id, sa.product_id
)
SELECT s.store_name, s.store_size_category,
       ROUND(AVG(si.reorder_level), 1) as avg_reorder_level,
       ROUND(AVG(COALESCE(mv.avg_monthly_sales, 0)), 2) as avg_monthly_sales_per_sku,
       ROUND(AVG(si.reorder_level) / NULLIF(AVG(COALESCE(mv.avg_monthly_sales,0)),0), 1) as reorder_covers_months
FROM store_inventory si
JOIN stores s ON si.store_id = s.store_id
LEFT JOIN monthly_velocity mv ON si.store_id = mv.store_id AND si.product_id = mv.product_id
GROUP BY s.store_id, s.store_name, s.store_size_category
ORDER BY avg_monthly_sales_per_sku DESC;

-- Query 23: H2. Reorder Level vs Velocity (Flagship vs Boutiques)
WITH monthly_velocity AS (
    SELECT sa.store_id, sa.product_id,
           CAST(SUM(sa.quantity_sold) AS FLOAT) / 12.0 as avg_monthly_sales
    FROM sales sa
    WHERE strftime('%Y', sa.sale_date) = '2025'
    GROUP BY sa.store_id, sa.product_id
)
SELECT s.store_name, s.store_size_category,
       si.reorder_level,
       ROUND(COALESCE(mv.avg_monthly_sales, 0), 2) as avg_monthly_sales
FROM store_inventory si
JOIN stores s ON si.store_id = s.store_id
LEFT JOIN monthly_velocity mv ON si.store_id = mv.store_id AND si.product_id = mv.product_id
WHERE s.store_id IN ('ST001','ST007','ST009','ST010');

-- Query 24: I1. Which products receive the most discounting, and where?
SELECT s.store_name, s.store_size_category,
       p.product_name, c.category_name, p.shelf_life_months,
       COUNT(*) as discounted_transactions,
       ROUND(AVG(sa.discount), 3) as avg_discount_rate,
       SUM(sa.quantity_sold) as units_sold_with_discount,
       ROUND(SUM(sa.total_amount), 2) as discounted_revenue
FROM sales sa
JOIN stores s ON sa.store_id = s.store_id
JOIN products p ON sa.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
WHERE sa.discount >= 0.15
GROUP BY sa.store_id, sa.product_id
HAVING COUNT(*) >= 3
ORDER BY avg_discount_rate DESC, discounted_transactions DESC;

-- Query 25: I.2. Cross-check: Are heavily discounted products also sitting in high inventory?
WITH discounted AS (
    SELECT sa.store_id, sa.product_id,
           ROUND(AVG(sa.discount),2) as avg_discount,
           SUM(sa.quantity_sold) as units_sold_discounted
    FROM sales sa
    WHERE sa.discount >= 0.15
    GROUP BY sa.store_id, sa.product_id
    HAVING COUNT(*) >= 3
)
SELECT s.store_name, s.store_size_category,
       p.product_name, p.shelf_life_months,
       si.quantity as current_stock,
       si.expiry_date,
       CAST(julianday(si.expiry_date) - julianday('2026-03-26') AS INTEGER) as days_to_expiry,
       d.avg_discount,
       d.units_sold_discounted,
       ROUND(p.unit_price, 2) as full_price
FROM discounted d
JOIN store_inventory si ON d.store_id = si.store_id AND d.product_id = si.product_id
JOIN stores s ON si.store_id = s.store_id
JOIN products p ON si.product_id = p.product_id
WHERE si.quantity > 50
ORDER BY si.quantity DESC;

-- Query 26: I.3. Compare same product sales at full price in large stores vs discounted in small stores
SELECT s.store_size_category,
       p.product_name,
       ROUND(AVG(sa.discount), 3) as avg_discount,
       ROUND(AVG(sa.unit_price), 2) as avg_selling_price,
       ROUND(AVG(sa.quantity_sold), 2) as avg_units_per_transaction,
       COUNT(*) as num_transactions
FROM sales sa
JOIN stores s ON sa.store_id = s.store_id
JOIN products p ON sa.product_id = p.product_id
WHERE sa.product_id IN ('PRD0174','PRD0170','PRD0072')
  AND s.store_id IN ('ST001','ST003','ST006','ST007','ST008')
GROUP BY s.store_size_category, sa.product_id
ORDER BY sa.product_id, s.store_size_category;
