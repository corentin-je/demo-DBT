# 🛍️ Ecommerce DBT Project

End‑to‑end dbt project for an ecommerce dataset, with intentionally “messy” raw data to practice **data cleaning, modeling, testing, and orchestration with Airflow**.

This project is the one you can safely **walk through live in an interview**: structure is clean, tests are in place, and the pipeline is orchestrated by Airflow.

---

## 📁 Project Structure

```text
ecommerce_dbt_project/
├── dbt_project.yml
├── packages.yml
├── README.md                  # This file
├── DATA/                      # Raw CSV data (for local load)
│   ├── raw_customers.csv
│   ├── raw_products.csv
│   ├── raw_orders.csv
│   ├── raw_order_items.csv
│   └── raw_payments.csv
├── models/
│   ├── sources.yml            # Source definitions (raw tables)
│   ├── staging/
│   │   ├── schema.yml
│   │   ├── stg_customers.sql
│   │   ├── stg_products.sql
│   │   ├── stg_orders.sql
│   │   ├── stg_order_items.sql
│   │   └── stg_payments.sql
│   ├── intermediate/
│   │   ├── int_customers.sql
│   │   ├── int_orders_enriched.sql
│   │   └── int_customer_lifetime.sql
│   └── marts/
│       ├── schema.yml
│       ├── fct_orders.sql
│       ├── dim_customers.sql
│       └── audit_data_quality.sql
├── tests/
│   ├── assert_positive_totals.sql
│   └── assert_volume_anomalies.sql
├── macros/                    # (reserved for custom macros, e.g. days_since)
├── snapshots/                 # (reserved for future SCD2 snapshots)
├── seeds/
└── airflow/
    ├── airflow.cfg
    ├── airflow.db
    └── dags/
        └── ecommerce_pipeline.py
```

> Note: `profiles.yml` is **not** inside this project; it lives in `~/.dbt/profiles.yml` as usual.

---

## 🚀 Quick Start

### 1️⃣ Load the Raw Data into PostgreSQL

Assuming you already have **PostgreSQL** running and a database (e.g. `ecommerce_db`), create a `raw` schema and load the CSV files from `DATA/`:

```sql
CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE raw.raw_customers (
    customer_id    VARCHAR,
    first_name     VARCHAR,
    last_name      VARCHAR,
    email          VARCHAR,
    signup_date    VARCHAR
);

-- Repeat similarly for raw_products, raw_orders, raw_order_items, raw_payments
```

Then from `psql`:

```bash
\COPY raw.raw_customers    FROM 'DATA/raw_customers.csv'    WITH (FORMAT csv, HEADER true);
\COPY raw.raw_products     FROM 'DATA/raw_products.csv'     WITH (FORMAT csv, HEADER true);
\COPY raw.raw_orders       FROM 'DATA/raw_orders.csv'       WITH (FORMAT csv, HEADER true);
\COPY raw.raw_order_items  FROM 'DATA/raw_order_items.csv'  WITH (FORMAT csv, HEADER true);
\COPY raw.raw_payments     FROM 'DATA/raw_payments.csv'     WITH (FORMAT csv, HEADER true);
```

### 2️⃣ Configure dbt Profile

In `~/.dbt/profiles.yml`:

```yaml
ecommerce_dbt_project:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      user: dbt_user
      password: [your_password]
      port: 5432
      dbname: ecommerce_db
      schema: ecommerce_dev
      threads: 4
      keepalives_idle: 0
```

### 3️⃣ Install Dependencies & Validate

```bash
cd /Users/corentinjegu/Documents/DEV/DBT_expert/ecommerce_dbt_project

dbt deps          # install packages (if any)
dbt debug         # check connection and profile
dbt parse         # validate project structure
```

### 4️⃣ Run the Pipeline Locally

```bash
dbt run           # build all models
dbt test          # run all tests

dbt docs generate
dbt docs serve    # open http://localhost:8000
```

---

## 📊 Data Flow (High-Level)

```text
Raw Data (PostgreSQL, schema: raw)
    ↓
Staging (5 models: stg_customers, stg_products, stg_orders, stg_order_items, stg_payments)
    ↓  (cleaning & basic tests)
Intermediate (3 models: int_customers, int_orders_enriched, int_customer_lifetime)
    ↓  (joins & business aggregations)
Marts (3 models: fct_orders, dim_customers, audit_data_quality)
    ↓  (data contracts + tests + audit)
Analytics (dashboards, reports, ad‑hoc analysis)
```

---

## 🎯 DBT Layers in This Project

### 1️⃣ Staging Layer (Cleaning & Typing)

Each raw table has a staging model:

| Raw table        | Staging model      | Purpose                              |
|------------------|--------------------|--------------------------------------|
| `raw_customers`  | `stg_customers`    | Deduplicate, normalize email, dates |
| `raw_products`   | `stg_products`     | Cast prices, clean stock quantity   |
| `raw_orders`     | `stg_orders`       | Normalize order status & dates      |
| `raw_order_items`| `stg_order_items`  | Basic integrity checks              |
| `raw_payments`   | `stg_payments`     | Normalize payment methods & status  |

**Typical logic in staging:**
- `ROW_NUMBER()` to deduplicate customers  
- `CASE WHEN ... THEN ... END` to handle bad formats  
- `TO_DATE()` and `CAST(.. AS NUMERIC)` for types  
- `LOWER(email)` to standardize  

Staging is where we accept “dirty” raw data and output **consistent, typed, row‑level data**.

---

### 2️⃣ Intermediate Layer (Enrichment & 3NF)

Goals:
- Decouple marts from staging (marts never depend directly on `stg_*`)  
- Central place for **business aggregations** and **joins**  

Key models:

- `int_customers.sql`  
  Simple pass‑through of `stg_customers` (copy in intermediate layer), acting as a **buffer** and future location for customer‑level enrichments.

- `int_orders_enriched.sql`  
  Joins orders with customers, order_items, and (via aggregation) payments to produce one enriched row per order.

- `int_customer_lifetime.sql`  
  Aggregates at customer level:
  - total_orders  
  - completed_orders  
  - total_spent  
  - avg_order_value  
  - first_order_date / last_order_date  

Intermediate models are the **business-ready relational layer** used by marts.

---

### 3️⃣ Marts Layer (Analytics / Star Schema)

#### Fact Table: `fct_orders`

Grain: **one row per order**.

Columns (non‑exhaustive):
- `order_key` (surrogate key, via dbt_utils or manual hash)  
- `order_id`, `customer_id`, `order_date`  
- `total_amount` (from orders)  
- `total_paid`, `payment_count` (from payments)  
- `payment_difference` (total_paid − total_amount)  
- `order_status`, `order_category` (e.g. underpaid / overpaid / balanced)  

Tests (see `models/marts/schema.yml`):
- `unique` + `not_null` on `order_id`  
- relationships from `customer_id` → `dim_customers.customer_id`  
- `total_amount` and `total_paid` should be ≥ 0  

#### Dimension Table: `dim_customers`

Grain: **one row per customer**.

Columns (non‑exhaustive):
- `customer_id`, `first_name`, `last_name`, `email`, `signup_date`  
- `total_orders`, `completed_orders`, `cancelled_orders`  
- `total_revenue` / `customer_lifetime_value`  
- `avg_order_value` (rounded to 2 decimals)  
- `days_since_last_order` (via `days_since` macro or direct date diff)  
- `customer_segment` (e.g. VIP / Loyal / New / Churn‑risk)  

Tests:
- `customer_id` `unique` + `not_null`  
- `total_orders` ≥ 0, `total_revenue` ≥ 0  

#### Audit Model: `audit_data_quality`

Purpose: **volume anomaly detection across layers**.

Outputs one row per monitored table, with:
- `table_name`  
- `expected_min`, `expected_max` (row count thresholds)  
- `actual_count`  
- `quality_status` ∈ {`OK`, `ALERT_LOW`, `ALERT_HIGH`}  

Used together with the custom test `assert_volume_anomalies.sql` to fail the build if critical volume issues are detected.

---

## ✅ Tests & Data Quality

### Schema Tests (YAML)

Defined in `models/staging/schema.yml` and `models/marts/schema.yml`:

```yaml
models:
  - name: fct_orders
    config:
      contract:
        enforced: true
    columns:
      - name: order_id
        description: Business order identifier
        tests:
          - not_null
          - unique
      - name: customer_id
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id
      - name: total_amount
        tests:
          - not_null
```

### Custom Tests

Located in `tests/`:

- `assert_positive_totals.sql`  
  Ensures no customer has negative total amounts:

```sql
SELECT customer_id, SUM(total_amount) AS total
FROM {{ ref('fct_orders') }}
GROUP BY customer_id
HAVING SUM(total_amount) < 0;
```

- `assert_volume_anomalies.sql`  
  Fails if `audit_data_quality` flags `ALERT_LOW` or `ALERT_HIGH`:

```sql
SELECT *
FROM {{ ref('audit_data_quality') }}
WHERE quality_status IN ('ALERT_LOW', 'ALERT_HIGH');
```

If this query returns rows, the test fails, surfacing volume anomalies.

### Data Contracts

`fct_orders` and `dim_customers` have **enforced contracts** (via `config.contract.enforced: true` in `models/marts/schema.yml`), meaning:
- dbt checks column presence & types at parse time  
- If the database schema drifts from the contract, builds fail early  

---

## 🔄 Airflow Orchestration

Airflow is configured **inside this project** for local orchestration:

```text
ecommerce_dbt_project/
└── airflow/
    ├── airflow.cfg
    ├── airflow.db          # local SQLite metadata
    └── dags/
        └── ecommerce_pipeline.py
```

### DAG: `ecommerce_dbt_pipeline`

Simplified structure (see full file for details):

```python
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.utils.dates import days_ago
from datetime import timedelta

DEFAULT_ARGS = {
    "owner": "data_engineering",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "start_date": days_ago(1),
}

dag = DAG(
    "ecommerce_dbt_pipeline",
    description="Daily ecommerce DBT pipeline: run → test → docs",
    schedule_interval="0 6 * * *",  # daily at 06:00
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["ecommerce", "dbt", "daily"],
    on_success_callback=dag_success_callback,
    on_failure_callback=dag_failure_callback,
)

dbt_run = BashOperator(
    task_id="dbt_run",
    bash_command=(
        "cd /Users/corentinjegu/Documents/DEV/DBT_expert/ecommerce_dbt_project "
        "&& dbt run --profiles-dir ~/.dbt"
    ),
    dag=dag,
)

dbt_test = BashOperator(
    task_id="dbt_test",
    bash_command=(
        "cd /Users/corentinjegu/Documents/DEV/DBT_expert/ecommerce_dbt_project "
        "&& dbt test --profiles-dir ~/.dbt"
    ),
    dag=dag,
)

dbt_docs = BashOperator(
    task_id="dbt_docs_generate",
    bash_command=(
        "cd /Users/corentinjegu/Documents/DEV/DBT_expert/ecommerce_dbt_project "
        "&& dbt docs generate --profiles-dir ~/.dbt"
    ),
    dag=dag,
)

dbt_run >> dbt_test >> dbt_docs
```

There are also **callbacks** (`dag_success_callback`, `dag_failure_callback`, `task_success_callback`, `task_failure_callback`) that log clear messages when the DAG or tasks succeed/fail, visible in Airflow logs and the terminal.

To run locally:

```bash
cd /Users/corentinjegu/Documents/DEV/DBT_expert/ecommerce_dbt_project
export AIRFLOW_HOME=$(pwd)/airflow

# Terminal 1
airflow scheduler

# Terminal 2
airflow webserver --port 8080
# Open http://localhost:8080  (admin / admin)
```

---

## 📚 Documentation (dbt docs)

Generate and explore documentation:

```bash
dbt docs generate
dbt docs serve
# Open http://localhost:8000
```

You’ll get:
- A **lineage graph** from raw → staging → intermediate → marts  
- Model and column descriptions (from `schema.yml`)  
- Tests attached to each column  
- Direct links to compiled SQL  

This is perfect to screen‑share in an interview.

---

## 🎯 How to Present This Project in an Interview

Short, punchy summary you can use:

> “I built a complete ecommerce analytics pipeline with dbt and Airflow:
> - 5 raw tables with intentional data quality issues  
> - 3 dbt layers (staging → intermediate → marts)  
> - 50+ tests (schema + custom) and enforced data contracts  
> - An audit model + custom test for volume anomalies  
> - Airflow DAG that orchestrates `dbt run`, `dbt test`, and `dbt docs` daily  
> - All code versioned and ready to demo on GitHub / locally.”

---

## 🎓 Learning Outcomes

By working through this project you practice:

- ✅ Full **dbt architecture** (staging / intermediate / marts)  
- ✅ **Data quality**: tests, contracts, and an audit model  
- ✅ Handling **dirty real‑world data** in staging  
- ✅ Designing **reusable** models and intermediate layers  
- ✅ Basic **governance**: metadata, lineage, documentation  
- ✅ **Orchestration** with Airflow (local, but production‑inspired)  
- ✅ Building a **portfolio‑ready project** you can defend in an interview  

---

**Good luck, and feel free to extend this project (e.g. snapshots, more marts, more tests) as you grow. 🚀**
