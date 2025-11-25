# 🛍️ Ecommerce DBT Project

**Objectif :** Projet DBT complet pour une plateforme ecommerce, avec données brutes intentionnellement "sales" pour pratiquer le nettoyage et la qualité.

**Timeline :** 2 jours (Mardi + Mercredi)  
**Format :** Staging → Intermediate → Marts + Tests + Data Contracts + Airflow

---

## 📁 Structure du projet

```
ecommerce_dbt_project/
├── dbt_project.yml          # Config DBT
├── profiles.yml             # Connexion DB (à configurer)
├── README.md                # Ce fichier
├── DATA_SETUP.md            # Instructions setup données
├── data/                    # CSV bruts
│   ├── raw_customers.csv
│   ├── raw_products.csv
│   ├── raw_orders.csv
│   ├── raw_order_items.csv
│   └── raw_payments.csv
├── models/
│   ├── _documentation.yml   # Global documentation
│   ├── staging/
│   │   ├── schema.yml
│   │   ├── stg_customers.sql
│   │   ├── stg_products.sql
│   │   ├── stg_orders.sql
│   │   ├── stg_order_items.sql
│   │   └── stg_payments.sql
│   ├── intermediate/
│   │   ├── schema.yml
│   │   ├── int_orders_enriched.sql
│   │   └── int_customer_lifetime.sql
│   └── marts/
│       ├── schema.yml
│       ├── fct_orders.sql
│       ├── dim_customers.sql
│       └── audit_data_quality.sql
├── tests/
│   ├── custom_tests/
│   │   ├── assert_positive_revenue.sql
│   │   └── assert_valid_payment_methods.sql
│   └── generic_tests/  (via schema.yml)
├── macros/
│   ├── days_since.sql
│   └── generate_business_day_diff.sql
├── snapshots/
│   └── snap_dim_customers.sql
└── dags/
    └── ecommerce_pipeline.py  # Airflow DAG
```

---

## 🚀 Quick Start

### 1️⃣ Setup PostgreSQL + Données

Voir `DATA_SETUP.md` pour les instructions détaillées.

```bash
# Create DB & tables
psql postgres -f DATA_SETUP.md

# Load CSVs
\COPY raw.raw_customers FROM 'data/raw_customers.csv' WITH (FORMAT csv, HEADER true);
# ... (répéter pour tous les fichiers)
```

### 2️⃣ Configure DBT

```bash
# Update profiles.yml
vim ~/.dbt/profiles.yml

# Ajouter :
ecommerce_dbt:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      user: dbt_user
      password: [your_password]
      port: 5432
      dbname: ecommerce_prod
      schema: ecommerce_dev
      threads: 4
      keepalives_idle: 0
```

### 3️⃣ Initialize DBT Project

```bash
cd ecommerce_dbt_project
dbt deps         # Install packages
dbt debug        # Test connection
dbt parse        # Parse models
```

### 4️⃣ Run Models

```bash
dbt run          # Run all models
dbt test         # Run tests
dbt docs generate
dbt docs serve   # View documentation
```

---

## 📊 Data Flow

```
Raw Data (5 tables)
    ↓
Staging (5 models - CLEAN)
    ↓ Tests (unique, not_null, relationships)
Intermediate (2 models - ENRICH)
    ↓ Tests
Marts (2 models - AGGREGATE)
    ↓ Data Contracts + Tests
Analytics (Dashboards / APIs)
```

---

## 🎯 Couches DBT

### **Couche 1 : Staging (Nettoyage)**

Chaque modèle raw a son stg équivalent :

| Raw | Staging | Nettoyage |
|-----|---------|-----------|
| `raw_customers` | `stg_customers` | Dédup, normalise email, dates |
| `raw_products` | `stg_products` | Type conversions (price) |
| `raw_orders` | `stg_orders` | Normalise statuts, dates |
| `raw_order_items` | `stg_order_items` | Valide intégrité |
| `raw_payments` | `stg_payments` | Normalise methods, statuts |

**Tests staging :**
- `unique` : pas de doublons clés
- `not_null` : colonnes obligatoires
- `relationships` : clés externes valides
- `accepted_values` : domaines fermés

---

### **Couche 2 : Intermediate (Enrichissement)**

| Modèle | Entrées | Sortie |
|--------|---------|--------|
| `int_orders_enriched` | stg_orders + stg_customers + stg_order_items | Orders avec client & produits |
| `int_customer_lifetime` | int_orders_enriched | CLV, AOV, order_count par customer |

**Objectif :** Préparer les données pour les marts (dimensions/faits)

---

### **Couche 3 : Marts (Analytics)**

#### Fact Table : `fct_orders`
```sql
-- Columns:
- order_key (surrogate, generated via dbt_utils)
- order_id
- customer_id
- order_date
- order_total
- payment_total
- payment_count
- order_category
- is_payment_complete

-- Tests:
- order_id UNIQUE + NOT NULL
- customer_id references dim_customers
- order_total > 0
```

#### Dimension Table : `dim_customers`
```sql
-- Columns:
- customer_id
- first_name, last_name, email
- signup_date
- total_orders
- completed_orders
- cancelled_orders
- customer_lifetime_value (CLV)
- avg_order_value
- customer_segment (VIP/Loyal/Regular)
- is_active_customer (last 90 days)
- days_since_last_order

-- Tests:
- customer_id UNIQUE + NOT NULL
- total_orders > 0
- customer_lifetime_value > 0

-- Data Contract:
- Schéma garanti (colonnes, types, nullability)
```

#### Audit Model : `audit_data_quality`
```sql
-- Monitor:
- Row counts (raw vs staging vs marts)
- Volume anomalies (alert if > ±20%)
- Data freshness (last updated timestamp)
```

---

## ✅ Tests & Quality

### Generic Tests (via schema.yml)

```yaml
tests:
  - unique: [order_id]
  - not_null: [customer_id]
  - relationships:
      column: customer_id
      to: ref('dim_customers')
      field: customer_id
  - accepted_values:
      values: ['completed', 'pending', 'cancelled']
```

### Custom Tests

```sql
-- tests/assert_positive_revenue.sql
SELECT customer_id, SUM(order_total) as total
FROM {{ ref('fct_orders') }}
GROUP BY customer_id
HAVING SUM(order_total) < 0
```

### Data Contracts

```yaml
# models/marts/schema.yml
- name: fct_orders
  config:
    contract:
      enforced: true
  columns:
    - name: order_id
      data_type: integer
      constraints:
        - type: not_null
        - type: unique
```

---

## 📈 Macros

### `days_since(date_column)`
Calcule le nombre de jours depuis une date donnée :
```sql
SELECT 
    customer_id,
    {{ days_since('last_order_date') }} as days_since_last_order
FROM int_customer_lifetime
```

### `generate_business_day_diff(start_date, end_date)`
Calcule business days (excluant weekends) :
```sql
SELECT 
    order_id,
    {{ generate_business_day_diff('order_date', 'delivery_date') }} as fulfillment_days
FROM fct_orders
```

---

## 📸 Snapshots (SCD Type 2)

Track customer dimension changes over time :

```sql
-- snapshots/snap_dim_customers.sql
SELECT 
    customer_id,
    customer_segment,
    customer_lifetime_value,
    is_active_customer
FROM {{ ref('dim_customers') }}
```

**Colonnes auto :**
- `dbt_valid_from` : quand changement detecté
- `dbt_valid_to` : quand nouveau changement
- `dbt_scd_id` : hash unique
- `dbt_updated_at` : timestamp du changement

---

## 🔄 Airflow Orchestration

DAG simple qui orchestre le pipeline DBT :

```python
# dags/ecommerce_pipeline.py
from airflow import DAG
from airflow.operators.bash import BashOperator

with DAG(
    'ecommerce_dbt_pipeline',
    schedule_interval='0 2 * * *',  # Daily 2am
    ...
) as dag:
    dbt_run >> dbt_test >> dbt_docs
```

**Tâches :**
1. `dbt_run` : Exécuter les modèles
2. `dbt_test` : Lancer les tests
3. `dbt_docs` : Générer documentation

**Alertes :**
- Slack notification si failures
- Retry automatique (1x)

---

## 📚 Documentation

### Auto-Generated (dbt docs)

```bash
dbt docs generate
dbt docs serve
# Browse http://localhost:8080
```

**Contient :**
- Lineage graph (raw → staging → intermediate → marts)
- Description de chaque modèle
- Descriptions de colonnes
- SQL queries
- Tests appliqués

### Business Glossary

```yaml
# models/_business_glossary.yml
terms:
  - name: CLV
    description: Customer Lifetime Value = Total revenue par customer
    synonyms: [total_spent, lifetime_value]
```

---

## 🎯 Checklist Completion

### Day 1 (Mardi)
- [ ] Setup PostgreSQL + données CSV chargées
- [ ] 5 modèles staging complets + tests
- [ ] 2 modèles intermediate complets
- [ ] 2 modèles marts (fct + dim) complets
- [ ] 30+ tests DBT passant
- [ ] Data contracts sur marts
- [ ] Audit model operational
- [ ] Documentation dbt docs générée

### Day 2 (Mercredi)
- [ ] Airflow DAG simple operationnel
- [ ] Tests + Great Expectations (optionnel)
- [ ] Portfolio GitHub : push complet
- [ ] Mock interview (3-4h)
- [ ] Repos finals : Jaffle Shop + ecommerce
- [ ] Sommeil 8h minimum 😴

---

## 🚀 Usage en Interview

**Comment référencer ce projet :**

> "J'ai construit hier un pipeline ecommerce complet :
> - 5 sources raw avec 30+ data quality issues
> - 3 couches DBT (staging/intermediate/marts)
> - 30+ tests + data contracts
> - 2 tables analytics-ready (facts + dimensions)
> - Orchestré avec Airflow (daily trigger)
> - Portfolio sur GitHub"

---

## 📞 Troubleshooting

### Erreur : "relation does not exist"
```
→ Vérifiez permissions dbt_user sur schema raw
GRANT SELECT ON ALL TABLES IN SCHEMA raw TO dbt_user;
```

### Erreur : "type mismatch"
```
→ Vérifiez data contracts vs données réelles
dbt parse --select fct_orders
```

### Erreur : "Airflow DAG not found"
```
→ Vérifiez $AIRFLOW_HOME/dags/ecommerce_pipeline.py existe
```

---

## 🎓 Learning Outcomes

Après ce projet, vous maîtriserez :

✅ Architecture DBT complète (3 couches)  
✅ Data quality (tests, contracts, audit)  
✅ Nettoyage données réalistes  
✅ Macros + code réutilisable  
✅ Governance (metadata, lineage, documentation)  
✅ Orchestration (Airflow basics)  
✅ Portfolio-ready code  

---

**Bonne chance ! 🚀**

Pour questions : voir DATA_SETUP.md et dbt docs



