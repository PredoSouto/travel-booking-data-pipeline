# 🏨 Travel Booking Data Pipeline

[![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://www.python.org/)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-2022-red.svg)](https://www.microsoft.com/sql-server)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-In%20Development-yellow)]()

> **Data engineering pipeline for a travel booking platform.**
>
> Full implementation of a Data Warehouse with Star Schema modeling, SCD Type 2, and automated ETL pipeline.

---

## 📋 Project Status

| Phase | Status | Completion |
|-------|--------|------------|
| Dimensional modeling | ✅ Done | 100% |
| SQL Server database | ✅ Done | 100% |
| SCD Type 2 stored procedures | ✅ Done | 100% |
| Fake data generator | ✅ Done | 100% |
| Python → SQL Server integration | ✅ Done | 100% |
| Airflow DAGs | 🔄 In progress | 0% |
| Automated tests | ⏳ Pending | 0% |
| CI/CD with GitHub Actions | ⏳ Pending | 0% |
| Full documentation | 🔄 In progress | 60% |

---

## 🎯 Objective

Build a **complete Data Warehouse** for business analysis of a travel booking platform (similar to Airbnb/Booking), showcasing skills in:

- ✅ Dimensional modeling (Star Schema)
- ✅ SCD Type 2 (Slowly Changing Dimensions)
- ✅ ETL with Python and SQL Server
- ✅ Realistic synthetic data generation
- ✅ Data engineering best practices

---

## 🏗️ Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     Python      │     │   SQL Server    │     │      Data       │
│    Generator    │────▶│    Staging      │────▶│    Warehouse    │
│    (Faker)      │     │    (Tables)     │     │  (Star Schema)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                │                        │
                                ▼                        ▼
                        ┌─────────────────┐     ┌─────────────────┐
                        │    Airflow      │     │   Power BI /    │
                        │    (Future)     │     │   Analytics     │
                        └─────────────────┘     └─────────────────┘
```

### Star Schema Model

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  dim_users   │     │  dim_hosts   │     │dim_properties│
│ (SCD Type 2) │     │ (SCD Type 2) │     │ (SCD Type 2) │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │
       └────────────────────┼────────────────────┘
                            ▼
                   ┌────────────────┐
                   │ fact_bookings  │
                   │    (Fact)      │
                   └───────┬────────┘
                           │
                           ▼
                   ┌────────────────┐
                   │ fact_payments  │
                   │    (Fact)      │
                   └────────────────┘

┌──────────────┐
│  dim_dates   │──────┘
│ (Calendar)   │
└──────────────┘
```

---

## 🛠️ Tech Stack

| Category | Technologies |
|----------|--------------|
| **Database** | Microsoft SQL Server 2022 |
| **Language** | Python 3.10+, T-SQL |
| **Data Generation** | Faker, Pandas, NumPy |
| **Orchestration** | Apache Airflow (planned) |
| **Containerization** | Docker, Docker Compose |
| **Version Control** | Git, GitHub |

---

## 📁 Project Structure

```
travel-booking-data-pipeline/
│
├── src/
│   ├── sql/                          # SQL scripts (12 files)
│   │   ├── 01_create_database_schemas.sql
│   │   ├── 02_control_etl.sql
│   │   ├── 03_create_table_users.sql
│   │   ├── 04_create_table_date.sql
│   │   ├── 05_create_table_dim_properties.sql
│   │   ├── 06_create_table_booking.sql
│   │   ├── 07_create_table_hosts.sql
│   │   ├── 08_create_table_payments.sql
│   │   ├── 09_create_table_reviews.sql
│   │   ├── 10_create_staging_tables.sql
│   │   ├── 11_populate_dim_dates.sql
│   │   └── 12_create_procedures_merge.sql
│   │
│   └── python/
│       ├── generators/
│       │   └── main.py               # Data generator + loader
│       ├── loaders/
│       │   └── load_to_sqlserver.py  # Connection and loading
│       └── utils/
│           └── config.py             # Settings
│
├── data/                             # Data (ignored by Git)
│   ├── raw/                          # Parquet files
│   └── metadata/                     # JSON schema
│
├── docs/                             # Documentation
├── tests/                            # Tests (future)
├── .env.example                      # Configuration example
├── .gitignore
├── requirements.txt
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

- Python 3.10+
- SQL Server 2022 (Developer Edition or LocalDB)
- ODBC Driver 17 for SQL Server

### 1. Environment Setup

```bash
# Clone the repository
git clone https://github.com/PredoSouto/travel-booking-data-pipeline
cd travel-booking-data-pipeline

# Create a virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt

# Set up environment variables
cp .env.example .env
# Edit the .env file with your SQL Server credentials
```

### 2. Create the Database

Run the SQL scripts in the following order (in SSMS or Azure Data Studio):

```
1.  01_create_database_schemas.sql
2.  02_control_etl.sql
3.  03_create_table_users.sql
4.  04_create_table_date.sql
5.  05_create_table_dim_properties.sql
6.  06_create_table_booking.sql
7.  07_create_table_hosts.sql
8.  08_create_table_payments.sql
9.  09_create_table_reviews.sql
10. 10_create_staging_tables.sql
11. 11_populate_dim_dates.sql
12. 12_create_procedures_merge.sql
```

### 3. Generate and Load Data

```bash
# Generate Parquet files only
python src/python/generators/main.py

# Generate and load into SQL Server
python src/python/generators/main.py --load-sql

# Full pipeline (generate + load + run merges)
python src/python/generators/main.py --load-sql --merge --truncate
```

### 4. Verify the Data

```sql
-- Check dimensions
SELECT * FROM dwh.dim_users WHERE is_current = 1;
SELECT * FROM dwh.dim_properties WHERE is_current = 1;

-- Check facts
SELECT COUNT(*) FROM dwh.fact_bookings;
SELECT COUNT(*) FROM dwh.fact_payments;

-- Check SCD history
EXEC dwh.sp_get_user_history @user_id = 1;

-- Check ETL logs
EXEC dwh.sp_get_etl_summary @days_back = 7;
```

---

## 📊 Analytical Query Examples

### Daily Revenue (YTD)

```sql
SELECT
    d.full_date,
    SUM(fb.total_price)                                   AS daily_revenue,
    SUM(SUM(fb.total_price)) OVER (ORDER BY d.full_date)  AS revenue_ytd
FROM dwh.fact_bookings fb
JOIN dwh.dim_dates d ON fb.checkin_date_sk = d.date_sk
WHERE fb.booking_status = 'completed'
GROUP BY d.full_date
ORDER BY d.full_date;
```

### Top 10 Properties by Revenue

```sql
SELECT TOP 10
    p.title,
    p.city,
    COUNT(DISTINCT fb.booking_id) AS total_bookings,
    SUM(fb.total_price)           AS total_revenue
FROM dwh.fact_bookings fb
JOIN dwh.dim_properties p ON fb.property_sk = p.property_sk
WHERE p.is_current = 1
  AND fb.booking_status = 'completed'
GROUP BY p.title, p.city
ORDER BY total_revenue DESC;
```

### Cancellation Rate by Property Type

```sql
SELECT
    p.property_type,
    COUNT(*)                                                                     AS total_bookings,
    SUM(CASE WHEN fb.booking_status = 'cancelled' THEN 1 ELSE 0 END)            AS cancelled_bookings,
    CAST(
        SUM(CASE WHEN fb.booking_status = 'cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
        AS DECIMAL(5,2)
    )                                                                            AS cancellation_rate
FROM dwh.fact_bookings fb
JOIN dwh.dim_properties p ON fb.property_sk = p.property_sk
WHERE p.is_current = 1
GROUP BY p.property_type
ORDER BY cancellation_rate DESC;
```

---

## 📈 Generated Data Volumes

| Table | Records | Size (approx.) |
|-------|---------|----------------|
| users | 10,000 | ~2 MB |
| hosts | 2,000 | ~0.5 MB |
| properties | 5,000 | ~3 MB |
| bookings | 50,000 | ~8 MB |
| payments | 48,000 | ~6 MB |
| **Total** | **115,000+** | **~20 MB** |

---

## ✅ What's Already Working

- ✅ Full ETL database setup
- ✅ Star Schema with 5 dimensions and 2 fact tables
- ✅ SCD Type 2 implemented via stored procedures
- ✅ Realistic synthetic data generation (115k+ records)
- ✅ Automated loading into SQL Server
- ✅ Calendar table (`dim_dates`) populated (2020–2030)
- ✅ ETL process logging and auditing
- ✅ Per-user change history

---

## 🔜 Next Steps

- [ ] Implement Apache Airflow DAGs
- [ ] Add unit and integration tests
- [ ] Set up GitHub Actions (CI/CD)
- [ ] Build a dashboard in Power BI or Superset
- [ ] Add data quality validations with Great Expectations
- [ ] Implement fact table partitioning
- [ ] Document the data access API

---

## 📝 Pending Documentation

| Document | Status | Priority |
|----------|--------|----------|
| README.md (this file) | 🔄 In progress | High |
| README.pt-BR.md | ⏳ Pending | Medium |
| Architecture diagram | ⏳ Pending | High |
| Contribution guide | ⏳ Pending | Low |
| Stored procedures docs | ⏳ Pending | Medium |

---

## 🤝 Contributing

This is a portfolio project, but contributions are welcome!

1. Fork the project
2. Create your branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.

---

## 📬 Contact

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue)](https://www.linkedin.com/in/pedro-guilherme-souto-de-oliveira-14a196165/)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-black)](https://github.com/PredoSouto)

---

*Built with ❤️ for the Data Engineering community — Last updated: May 2026*