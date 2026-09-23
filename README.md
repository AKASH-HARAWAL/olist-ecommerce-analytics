# Olist E-Commerce Analytics — End-to-End Business Analysis

An end-to-end data analytics project using PostgreSQL, Python, and Power BI to analyze 100K+ orders from Olist, a Brazilian e-commerce marketplace. This project covers database design, data cleaning, SQL analysis (including window functions, cohort analysis, and RFM segmentation), and a business-facing dashboard.

## Tech Stack
- **Database:** PostgreSQL
- **Analysis:** SQL (CTEs, window functions, views), Python (pandas)
- **Visualization:** Power BI
- **Version Control:** Git/GitHub

## Database Schema

![ERD Diagram](images/erd_diagram.png)

9 relational tables covering customers, orders, order items, payments, reviews, products, sellers, and geolocation data.

## Dataset
This project uses the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) from Kaggle. Download it and place the CSVs in a `data/` folder to reproduce this analysis.

## Project Structure

sql/ -- All SQL scripts (schema, cleaning, analysis, views)
notebooks/ -- Python data cleaning and profiling notebook
dashboard/ -- Power BI dashboard file
images/ -- ERD diagram and dashboard screenshots


## Analysis Highlights

*(Full write-up with insights and recommendations coming in the final project summary below — sections to be completed)*

- **Revenue & Growth:** Monthly revenue trends and MoM growth analysis
- **Customer Segmentation:** RFM analysis across 93K+ customers
- **Cohort Retention:** Month-over-month repeat purchase analysis
- **Delivery Performance:** Regional delivery delay analysis and its impact on customer reviews
- **Product & Seller Performance:** Category and seller revenue rankings

## Key Findings
*(To be added in final write-up)*

## Business Recommendations
*(To be added in final write-up)*

## Dashboard
*(Screenshot and link to be added once Power BI dashboard is complete)*

## How to Reproduce This Analysis
1. Clone this repo
2. Download the Olist dataset from Kaggle, place CSVs in `data/`
3. Run `sql/01_schema.sql` to create the database schema
4. Import the CSVs into PostgreSQL (see `sql/` folder for data quality notes)
5. Run analysis queries in `sql/03` through `sql/10` in order
6. Open `notebooks/01_data_cleaning.ipynb` for the data profiling process
7. Open the Power BI file in `dashboard/` to explore the interactive dashboard