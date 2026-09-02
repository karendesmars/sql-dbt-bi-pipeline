# SQL / dbt / BI Pipeline

**Status: pipeline written, not run yet.** The raw data has not been downloaded locally, so no model has been executed or tested against real rows.

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

Not written yet. This section will be filled in once the pipeline has been run and tested against the real data.
