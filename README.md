# FINANCIAL-360                      

** contact:** agrawalricha1983@gmail.com

## Project Overview

Financial 360 is an end-to-end banking analytics project built to analyze customer, account, transaction, loan, credit card, credit score and defaulter data.

The project demonstrates a complete analytics workflow:

**SQL → Python → DAX → Power BI**

The objective is to transform relational banking data into meaningful business insights, with a particular focus on customer financial activity, credit behaviour and risk analysis.

---

## Business Objectives

- Analyze customer financial activity
- Understand account and transaction patterns
- Analyze loans and loan status
- Identify and analyze defaulters
- Analyze customer credit scores and credit behaviour
- Compare financial activity across banks
- Track customer credit-score movement over time
- Build customer-level risk analysis
- Create an interactive banking analytics dashboard

---

## Database

The project uses a relational MySQL database containing the following key tables:

- Customers
- Banks
- Accounts
- Transactions
- Loans
- Credit Cards
- Credit Score
- Defaulters

---

## SQL Analysis

The project includes **21 business-oriented SQL queries**, progressing from fundamental analysis to advanced analytical and risk-focused queries.

### SQL Concepts Demonstrated

- SELECT and filtering
- JOINs
- GROUP BY and aggregate functions
- Subqueries
- Common Table Expressions (CTEs)
- CASE statements
- UNION
- COALESCE
- GROUP_CONCAT
- Window functions
- ROW_NUMBER
- LAG and LEAD
- NTILE
- ROLLUP
- EXISTS
- Ranking and analytical functions
- Stored procedures

### Query 21 — Credit Risk Analysis

Query 21 is the key risk-analysis query in the project.

It builds a customer-level credit history and credit trajectory from historical credit-score records. CTEs and window functions are used to organize credit-score history, track changes over time and generate customer-level credit metrics.

The output forms the foundation for the project's Python-based risk analysis and the Risk & Credit Analysis section of the Power BI dashboard.

---

## Python Risk Analysis

Python and Pandas are used to extend the SQL analysis and create a customer-level risk dataset.

The Python workflow:

- Connects to the MySQL database
- Executes the risk-analysis SQL
- Loads the results into Pandas
- Processes customer credit information
- Supports credit trajectory and risk analysis

---

## Power BI Dashboard

The SQL and Python analysis are presented through a **7-page interactive Power BI dashboard**.

### Dashboard Pages

#### 1. Financial 360 Overview

- Key financial KPIs
- Customer and account overview
- Transaction and loan exposure
- Bank-level analysis
- Defaulter percentage

#### 2. Risk & Credit Analysis

- Credit score analysis
- Customer risk status
- Credit score distribution
- Defaulter analysis

#### 3. Customer & Account Analysis

- Customer account distribution
- Account and balance analysis
- Customer-level financial activity

#### 4. Transaction Analysis

- Transaction volume
- Average transaction value
- Bank-level transaction analysis
- Transaction activity over time

#### 5. Loan Analysis

- Loan exposure
- Loan status
- Customer loan exposure
- Top customer loan analysis

#### 6. Defaulter & Customer Risk

- Defaulter analysis
- Customer risk indicators
- Loan exposure associated with risk

#### 7. Customer 360

- Customer-level financial profile
- Accounts
- Transactions
- Loans
- Credit score
- Defaulter status
- Loan status

---

## Tools & Technologies

- MySQL
- SQL
- MySQL Workbench
- Python
- Pandas
- Power BI
- DAX
- GitHub

---

## Project Workflow

```text
MySQL Database
      ↓
21 SQL Business Queries
      ↓
Python / Pandas Risk Analysis
      ↓
DAX Measures & Calculated Columns
      ↓
7-Page Power BI Dashboard
      ↓
Customer & Financial Risk Insights
