-- PopBeauty retail inventory database: schema (SQLite)
-- 9 tables in third normal form (3NF), matching the ER diagram (images/er-diagram.png).
-- Primary keys, foreign keys, unique keys and value checks are enforced by the database.

PRAGMA foreign_keys = ON;

CREATE TABLE brands (
    brand_id    TEXT PRIMARY KEY,
    brand_name  TEXT NOT NULL UNIQUE
);

CREATE TABLE categories (
    category_id    TEXT PRIMARY KEY,
    category_name  TEXT NOT NULL UNIQUE
);

CREATE TABLE products (
    product_id         TEXT PRIMARY KEY,
    product_name       TEXT NOT NULL,
    brand_id           TEXT NOT NULL REFERENCES brands (brand_id),
    category_id        TEXT NOT NULL REFERENCES categories (category_id),
    unit_price         REAL NOT NULL CHECK (unit_price >= 0),
    cost_price         REAL NOT NULL CHECK (cost_price >= 0),
    shelf_life_months  INTEGER CHECK (shelf_life_months > 0)
);

CREATE TABLE stores (
    store_id             TEXT PRIMARY KEY,
    store_name           TEXT NOT NULL UNIQUE,
    city                 TEXT NOT NULL,
    region               TEXT NOT NULL,
    store_size_category  TEXT NOT NULL
);

CREATE TABLE warehouses (
    warehouse_id    TEXT PRIMARY KEY,
    warehouse_name  TEXT NOT NULL UNIQUE,
    location        TEXT NOT NULL,
    capacity_units  INTEGER CHECK (capacity_units > 0)
);

CREATE TABLE store_inventory (
    inventory_id     TEXT PRIMARY KEY,
    store_id         TEXT NOT NULL REFERENCES stores (store_id),
    product_id       TEXT NOT NULL REFERENCES products (product_id),
    quantity         INTEGER NOT NULL CHECK (quantity >= 0),
    reorder_level    INTEGER CHECK (reorder_level >= 0),
    min_stock_level  INTEGER CHECK (min_stock_level >= 0),
    expiry_date      TEXT,
    last_updated     TEXT,
    UNIQUE (store_id, product_id)
);

CREATE TABLE warehouse_inventory (
    warehouse_inventory_id  TEXT PRIMARY KEY,
    warehouse_id            TEXT NOT NULL REFERENCES warehouses (warehouse_id),
    product_id              TEXT NOT NULL REFERENCES products (product_id),
    quantity_on_hand        INTEGER NOT NULL CHECK (quantity_on_hand >= 0),
    last_updated            TEXT,
    UNIQUE (warehouse_id, product_id)
);

CREATE TABLE shipments (
    shipment_id      TEXT PRIMARY KEY,
    warehouse_id     TEXT NOT NULL REFERENCES warehouses (warehouse_id),
    store_id         TEXT NOT NULL REFERENCES stores (store_id),
    product_id       TEXT NOT NULL REFERENCES products (product_id),
    quantity         INTEGER NOT NULL CHECK (quantity > 0),
    shipment_date    TEXT NOT NULL,
    received_date    TEXT,
    shipment_status  TEXT NOT NULL
);

CREATE TABLE sales (
    sale_id        TEXT PRIMARY KEY,
    store_id       TEXT NOT NULL REFERENCES stores (store_id),
    product_id     TEXT NOT NULL REFERENCES products (product_id),
    sale_date      TEXT NOT NULL,
    quantity_sold  INTEGER NOT NULL CHECK (quantity_sold > 0),
    unit_price     REAL NOT NULL CHECK (unit_price >= 0),
    total_amount   REAL NOT NULL,
    discount       REAL CHECK (discount BETWEEN 0 AND 1)
);

-- Indexes on the foreign keys most used in joins
CREATE INDEX idx_sales_store_product ON sales (store_id, product_id);
CREATE INDEX idx_store_inventory_product ON store_inventory (product_id);
CREATE INDEX idx_shipments_store ON shipments (store_id);
