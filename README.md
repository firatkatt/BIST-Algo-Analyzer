# BIST-Algo-Analyzer: Financial Data and News Analysis System

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Advanced-red?style=for-the-badge)

BIST-Algo-Analyzer is a comprehensive **relational database and decision support system** that integrates periodic price movements (OHLCV) of companies listed on the **Borsa İstanbul (BIST 100)** with sentiment analysis scores derived from announcements on the Public Disclosure Platform (KAP) into a single ecosystem. 

This project was designed as an academic exercise in “Database Engineering” and successfully models a large-scale financial data warehouse.

---

## 🚀 Project Outputs and Features

*   **100 Companies, Big Data Set:** A “Big Data” dataset of approximately **25,000 rows** covering one year of historical financial simulations and news feeds for 98 companies within the BIST100.
*   **Advanced SQL (Category 3):** An 8-table schema built with strict normalization rules (within the bounds of 1NF, 2NF, and 3NF);
    *   **Window Functions** (50-Day Simple Moving Average / SMA-50 Calculations)
    *   **CTEs & Views** (Views that simplify interlinked complex financial algorithms)
    *   **Complex JOINs & Aggregations** (Sector-specific NLP sentiment analysis) were utilized.
*   **Python Data Generation Bot:** A Python data generation architecture that provides real-time data via `yfinance` and features an automatic *Fallback (Realistic Synthetic Algorithm Generation)* infrastructure to address potential API or limit issues.

---

## 📂 Folder Structure

```text
├── data/
│   ├── Daily_Prices.csv           # Over 25,000 rows of OHLCV price history
│   ├── KAP_News.csv               # Corporate KAP news announcement articles
│   ├── News_Sentiments.csv        # Algorithmic NLP M:N mapping table
│   └── Sentiment_Dictionary.csv   # Sentiment dictionary (Scoring terms)
├── docs/
│   ├── technical_report.md        # Database ERD diagram and academic Problem Statement Report
│   └── technical_report.pdf       # Exported Database PDF Report
├── scripts/
│   └── data_builder.py            # Yfinance price fetching and OHLCV news/data bot
└── sql/
    ├── queries.sql                # Advanced analytical queries (CTEs, SMA, Window Functions)
    └── schema.sql                 # Complete 3NF SQL Database Schema with 8 Tables
```

---

## 💻 How to Run It?

### 1. Setting Up the Database (DB Manager)
1. Create an empty database in your preferred DBMS interface (DBeaver, pgAdmin, SQL Server Management Studio, etc.) and run the `sql/schema.sql` file to set up the architecture of the 8 related tables.
2. Use your software’s “Import Data” feature to load the CSV files in the `data/` folder into the corresponding tables column-by-column, following the relationship tree.
3. Run the demonstration-focused queries in `sql/queries.sql` to observe the data results of the investment algorithms.

### 2. (Optional) Regenerating Data
If you want to test the system, refresh the synthetic data, or run the bot again:
```bash
source env/bin/activate
python scripts/data_builder.py
```
*(The script will compile without issues and regenerate all your large CSV files in the data folder within seconds).*

---
*This project is structured according to advanced database application design standards focused on academic use.*
