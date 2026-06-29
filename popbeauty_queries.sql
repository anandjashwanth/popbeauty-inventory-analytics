-- ============================================================
-- PopBeauty Retail Inventory Analytics  |  SQL Queries
-- Module: IB9HP0 (Data Management)  |  Warwick Business School
-- Author of this analysis: Jashwanth Anand Shankar
--   (database build, SQL analysis, report) - group project, synthetic data
-- Engine: SQLite  |  Data: synthetic (fictional retailer "PopBeauty")
-- ============================================================
-- Business problem: inventory imbalance across a 13-store, 6-warehouse
-- network - stock exists but is allocated to the wrong stores. The queries
-- below diagnose misplacement, expiry risk, fulfilment bottlenecks,
-- reorder miscalibration and margin concentration.
-- ============================================================


-- ============================================================
-- SECTION 1 - SCHEMA (3NF relational design, 9 entities)
-- ============================================================

CREATE TABLE "brands" (
	"brand_id"	TEXT,
	"brand_name"	TEXT,
	PRIMARY KEY("brand_id")
);

CREATE TABLE "categories" (
	"category_id"	TEXT,
	"category_name"	TEXT,
	PRIMARY KEY("category_id")
);

CREATE TABLE "products" (
	"product_id"	TEXT,
	"product_name"	TEXT,
	"brand_id"	TEXT,
	"category_id"	TEXT,
	"unit_price"	REAL,
	"cost_price"	REAL,
	"shelf_life_months"	INTEGER,
	PRIMARY KEY("product_id")
);

CREATE TABLE "sales" (
	"sale_id"	TEXT,
	"store_id"	TEXT,
	"product_id"	TEXT,
	"sale_date"	TEXT,
	"quantity_sold"	INTEGER,
	"unit_price"	REAL,
	"total_amount"	REAL,
	"discount"	REAL
);

CREATE TABLE "shipments" (
"shipment_id" TEXT,
  "warehouse_id" TEXT,
  "store_id" TEXT,
  "product_id" TEXT,
  "quantity" INTEGER,
  "shipment_date" TEXT,
  "received_date" TEXT,
  "shipment_status" TEXT
);

CREATE TABLE "store_inventory" (
"inventory_id" TEXT,
  "store_id" TEXT,
  "product_id" TEXT,
  "quantity" INTEGER,
  "reorder_level" INTEGER,
  "min_stock_level" INTEGER,
  "expiry_date" TEXT,
  "last_updated" TEXT
);

CREATE TABLE "stores" (
"store_id" TEXT,
  "store_name" TEXT,
  "city" TEXT,
  "region" TEXT,
  "store_size_category" TEXT
);

CREATE TABLE "warehouse_inventory" (
"warehouse_inventory_id" TEXT,
  "warehouse_id" TEXT,
  "product_id" TEXT,
  "quantity_on_hand" INTEGER,
  "last_updated" TEXT
);

CREATE TABLE "warehouses" (
"warehouse_id" TEXT,
  "warehouse_name" TEXT,
  "location" TEXT,
  "capacity_units" INTEGER
);



-- ============================================================
-- SECTION 2 - ANALYTICAL QUERIES
-- ============================================================

-- 1. Store master list by size and region
SELECT store_id, store_name, city, region, store_size_category
    FROM stores
    ORDER BY store_size_category, store_name;

-- 2. Category overview - product counts and price bands
SELECT c.category_name,
           COUNT(DISTINCT p.product_id) as num_products,
           ROUND(AVG(p.unit_price), 2) as avg_price,
           ROUND(MIN(p.unit_price), 2) as min_price,
           ROUND(MAX(p.unit_price), 2) as max_price
    FROM products p
    JOIN categories c ON p.category_id = c.category_id
    GROUP BY c.category_name
    ORDER BY avg_price DESC;

-- 3. Total units on hand by store (inventory footprint)
SELECT s.store_name, s.store_size_category, s.region,
           COUNT(DISTINCT si.product_id) as distinct_skus,
           SUM(si.quantity) as total_units_on_hand,
           ROUND(AVG(si.quantity), 1) as avg_units_per_sku
    FROM store_inventory si
    JOIN stores s ON si.store_id = s.store_id
    GROUP BY s.store_id, s.store_name, s.store_size_category, s.region
    ORDER BY total_units_on_hand DESC;

-- 4. Sales performance by store (transactions, units, revenue)
SELECT s.store_name, s.store_size_category,
           COUNT(sa.sale_id) as num_transactions,
           SUM(sa.quantity_sold) as total_units_sold,
           ROUND(SUM(sa.total_amount), 2) as total_revenue,
           ROUND(AVG(sa.quantity_sold), 2) as avg_units_per_transaction
    FROM sales sa
    JOIN stores s ON sa.store_id = s.store_id
    GROUP BY s.store_id, s.store_name, s.store_size_category
    ORDER BY total_revenue DESC;

-- 5. Sell-through ratio - units sold vs units stocked (core 'misplacement' metric)
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

-- 6. Stores below minimum stock level (stockout situations)
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

-- 7. Overstock situations - stock far above reorder level
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

-- 8. Expiry risk - units held against days-to-expiry
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

-- 9. Category performance by store tier
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

-- 10. Premium Beauty Tools stock vs sales (Dyson/FOREO misallocation)
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

-- 11. Beauty Tools & Fragrance sell-through by store
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

-- 12. Gross profit and margin by category
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

-- 13. Gross profit by store
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

-- 14. Reorder level calibration - coverage months vs actual velocity
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

-- 15. North Warehouse stock vs store shortages
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

-- 16. Stuck shipments - 'ghost records' stuck In Transit
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

-- 17. Short shelf-life skincare by store (redistribution candidates)
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

-- 18. Scotland critical shortage on SKUs expiring elsewhere
SELECT sh.shipment_id,
           wh.warehouse_name, s.store_name, s.store_size_category,
           p.product_name,
           sh.quantity,
           sh.shipment_date,
           sh.received_date,147.6
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

-- 19. Discount vs full-price comparison by store tier
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

-- 20. Dead stock - high inventory near expiry despite discounts
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

-- 21. Estimated write-off value by location
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

-- 22. Premium tool sales by store
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

