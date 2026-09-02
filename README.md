# SQL / dbt / BI Pipeline

**Status: executed and tested.** `dbt run` (13 models) and `dbt test` (10 tests) both pass against the real dataset.

**Dataset:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), 9 relational CSV files (orders, order items, payments, reviews, customers, products, sellers, geolocation, category translation), about 100,000 orders
**Tools:** SQL, dbt (`dbt-duckdb`), DuckDB as the local warehouse
**Goal:** Build a proper staging -> intermediate -> marts transformation pipeline with dbt, on top of a real multi-table dataset, instead of a single flat CSV.

---

## Why dbt, and why this dataset

The other SQL portfolio project ([sql-sales-analytics](https://github.com/karendesmars/sql-sales-analytics)) uses a single flat table and plain SQL in a notebook. This project is meant to show a different skill: a versioned, tested, documented transformation pipeline with dbt, which only makes sense on a dataset with several related tables to join and model. Olist has 9 CSV files with real foreign keys between them (orders -> customers, order items -> products/sellers, orders -> payments), which is exactly the kind of structure dbt is built for.

---

## Project Structure

```
sql-dbt-bi-pipeline/
├── data/                                   # Raw CSVs, not tracked in git, see Data section below
├── models/
│   ├── staging/olist/                      # One model per raw source table, light cleaning/casting only
│   │   ├── _olist__sources.yml             # Declares the 9 raw CSV files as dbt sources
│   │   ├── stg_olist__orders.sql
│   │   ├── stg_olist__order_items.sql
│   │   ├── stg_olist__order_payments.sql
│   │   ├── stg_olist__order_reviews.sql
│   │   ├── stg_olist__customers.sql
│   │   ├── stg_olist__products.sql
│   │   ├── stg_olist__sellers.sql
│   │   ├── stg_olist__geolocation.sql
│   │   └── stg_olist__product_category_translation.sql
│   ├── intermediate/
│   │   └── int_order_payments_aggregated.sql   # Payments are at order grain, aggregated here before the fact table
│   └── marts/
│       ├── _marts__models.yml              # Tests: unique/not_null on keys, relationships between tables
│       ├── dim_customers.sql
│       ├── dim_products.sql                # Products joined with their English category name
│       └── fct_order_items.sql             # Main fact table: one row per order item
├── dbt_project.yml
├── environment.yml
└── README.md
```

---

## Data

The raw CSVs are not tracked in git (see `.gitignore`).

To reproduce:
1. Download the dataset from Kaggle: `kaggle datasets download -d olistbr/brazilian-ecommerce`
2. Unzip into `data/`, so dbt finds files like `data/olist_orders_dataset.csv`, `data/olist_order_items_dataset.csv`, etc.

The sources read the CSVs directly with DuckDB's `read_csv_auto` (see `models/staging/olist/_olist__sources.yml`), there is no separate CSV-loading step before running dbt.

---

## Running this project

```
conda env create -f environment.yml
conda activate sql-dbt-bi-pipeline

export DBT_ECOMMERCE_DB_PATH="$(pwd)/data/ecommerce.duckdb"
dbt debug     # checks the connection and project config
dbt run       # builds all staging, intermediate, and mart models
dbt test      # runs the data tests (uniqueness, not-null, relationships)
```

`DBT_ECOMMERCE_DB_PATH` points dbt to a local DuckDB file (created automatically on first run). This is set with an environment variable rather than hardcoded in `profiles.yml`, so the path is not tied to one specific machine, `profiles.yml` lives in `~/.dbt/` and is not part of this repo (standard dbt convention, keeps machine-specific config out of git).

Note: `conda env create -f environment.yml` creates the environment in conda's default location (`~/miniconda3/envs/`), not inside this project folder. dbt installs thousands of small package files, so keeping the environment out of any cloud-synced folder (iCloud Drive, Dropbox, etc.) avoids those files being silently offloaded and re-downloaded on every import, which can make commands like `dbt run` hang for minutes.

---

## Approach

| Layer | Models | Purpose |
|---|---|---|
| Staging | 9 models, one per raw table | Light cleaning: consistent column casing, casting date/timestamp columns. No joins, no business logic. |
| Intermediate | `int_order_payments_aggregated` | Aggregates payments (recorded per installment) up to one row per order, so the fact table can join a single payment total without duplicating rows. |
| Marts | `dim_customers`, `dim_products`, `fct_order_items` | Business-facing tables: a customer dimension, a product dimension (with English category names), and an order-item-grain fact table joining orders, items, and payment totals. |

`fct_order_items` also computes `delivery_days` (purchase to actual delivery) and `delivery_delay_days` (actual delivery vs estimated delivery), which is the main starting point for BI questions like on-time delivery rate or delivery performance by region.

---

## Data quality tests

`models/marts/_marts__models.yml` defines dbt tests on the mart layer:
- `unique` + `not_null` on `dim_customers.customer_id` and `dim_products.product_id`
- `not_null` on `fct_order_items.order_id`, `customer_id`, `product_id`, `price`
- `relationships` tests confirming every `customer_id` and `product_id` in the fact table exists in the corresponding dimension table

---

## BI layer

Not built yet. Power BI Desktop does not run on macOS; the plan is to either use Power BI Service (web) or Metabase against the DuckDB output. This section will be updated once that decision is made and the dashboard exists.

---

## Key Findings

- **The pipeline builds 99,441 unique customers, 32,951 products, and 112,650 order items** from the 9 raw CSVs, with all 10 data quality tests passing (no orphaned foreign keys between the fact table and the two dimensions).
- **Deliveries arrive early on average.** Across delivered orders, the average delivery takes 12.4 days, and lands 12.0 days *before* the estimated delivery date on average. Only 6.6% of order items are delivered later than their estimate. This suggests Olist's estimated delivery dates are set conservatively rather than being an accurate forecast, worth keeping in mind for anyone using `order_estimated_delivery_at` as a planning input.
- **Revenue is concentrated in a handful of categories.** The top 5 product categories by revenue are health_beauty ($1.26M), watches_gifts ($1.21M), bed_bath_table ($1.04M), sports_leisure ($988K), and computers_accessories ($912K). These figures come directly from `fct_order_items` joined to `dim_products`, the same query pattern the BI layer will build on.
