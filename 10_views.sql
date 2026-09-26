-- ============================================================
-- SQL VIEWS
-- Reusable, production-style versions of core analytical queries.
-- Power BI connects directly to these views instead of embedding 
-- raw SQL in the dashboard — cleaner, and changes only need to 
-- happen in one place.
-- ============================================================

-- View 1: Monthly revenue trend
CREATE VIEW vw_monthly_revenue AS
SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    SUM(p.payment_value) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp >= '2017-01-01'
GROUP BY 1;

-- PERFORMANCE NOTE (via EXPLAIN ANALYZE):
-- This query takes ~4.3 seconds on ~93K customers, primarily due to:
-- 1. Sequential scans on orders/customers/order_payments (no index on 
--    customer_id/order_id beyond primary keys)
-- 2. Three separate disk-based sorts (one per NTILE window function for 
--    recency, frequency, monetary scoring)
-- 
-- Potential optimization: adding indexes on orders.customer_id and 
-- order_payments.order_id would allow index scans instead of sequential 
-- scans on the join. However, since this is an analytical (not 
-- transactional) query run infrequently rather than on every page load, 
-- 4.3s is acceptable for this use case and an index wasn't added to avoid 
-- unnecessary write overhead on a read-heavy analytical database.

-- View 2: Customer RFM segments
CREATE VIEW vw_customer_rfm AS
WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        p.payment_value
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
),
rfm_base AS (
    SELECT 
        customer_unique_id,
        (SELECT MAX(order_purchase_timestamp) FROM customer_orders) - MAX(order_purchase_timestamp) AS recency_interval,
        COUNT(DISTINCT order_id) AS frequency,
        SUM(payment_value) AS monetary
    FROM customer_orders
    GROUP BY customer_unique_id
),
rfm_scored AS (
    SELECT 
        customer_unique_id,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_interval ASC) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS monetary_score
    FROM rfm_base
)
SELECT *,
    CASE 
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
        WHEN recency_score >= 3 AND frequency_score >= 3 THEN 'Loyal Customers'
        WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'New Customers'
        WHEN recency_score <= 2 AND frequency_score >= 3 THEN 'At Risk'
        WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'Lost'
        ELSE 'Needs Attention'
    END AS customer_segment
FROM rfm_scored;

-- View 3: Delivery performance by state
CREATE VIEW vw_delivery_by_state AS
SELECT 
    c.customer_state,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) AS late_delivery_pct,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 50;


CREATE VIEW vw_cohort_retention AS
WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
first_purchase AS (
    SELECT 
        customer_unique_id,
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS cohort_month
    FROM customer_orders
    GROUP BY customer_unique_id
),
customer_activity AS (
    SELECT 
        co.customer_unique_id,
        fp.cohort_month,
        DATE_TRUNC('month', co.order_purchase_timestamp) AS activity_month,
        (DATE_PART('year', DATE_TRUNC('month', co.order_purchase_timestamp)) - DATE_PART('year', fp.cohort_month)) * 12 +
        (DATE_PART('month', DATE_TRUNC('month', co.order_purchase_timestamp)) - DATE_PART('month', fp.cohort_month)) AS months_since_first_purchase
    FROM customer_orders co
    JOIN first_purchase fp ON co.customer_unique_id = fp.customer_unique_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS num_customers
    FROM first_purchase
    GROUP BY cohort_month
)
SELECT 
    ca.cohort_month,
    cs.num_customers AS cohort_size,
    ca.months_since_first_purchase,
    COUNT(DISTINCT ca.customer_unique_id) AS active_customers,
    ROUND(COUNT(DISTINCT ca.customer_unique_id) * 100.0 / cs.num_customers, 2) AS retention_pct
FROM customer_activity ca
JOIN cohort_size cs ON ca.cohort_month = cs.cohort_month
GROUP BY ca.cohort_month, cs.num_customers, ca.months_since_first_purchase
ORDER BY ca.cohort_month, ca.months_since_first_purchase;

-- View 4: CLV Tier Distribution
CREATE VIEW vw_clv_tiers AS
WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        p.payment_value
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
),
customer_metrics AS (
    SELECT 
        customer_unique_id,
        SUM(payment_value) AS total_spend
    FROM customer_orders
    GROUP BY customer_unique_id
)
SELECT 
    CASE 
        WHEN total_spend >= 1000 THEN 'High Value'
        WHEN total_spend >= 300 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS clv_tier,
    COUNT(*) AS num_customers,
    ROUND(AVG(total_spend), 2) AS avg_spend
FROM customer_metrics
GROUP BY clv_tier;

-- View 5: Cohort Retention
CREATE VIEW vw_cohort_retention AS
WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
first_purchase AS (
    SELECT 
        customer_unique_id,
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS cohort_month
    FROM customer_orders
    GROUP BY customer_unique_id
),
customer_activity AS (
    SELECT 
        co.customer_unique_id,
        fp.cohort_month,
        DATE_TRUNC('month', co.order_purchase_timestamp) AS activity_month,
        (DATE_PART('year', DATE_TRUNC('month', co.order_purchase_timestamp)) - DATE_PART('year', fp.cohort_month)) * 12 +
        (DATE_PART('month', DATE_TRUNC('month', co.order_purchase_timestamp)) - DATE_PART('month', fp.cohort_month)) AS months_since_first_purchase
    FROM customer_orders co
    JOIN first_purchase fp ON co.customer_unique_id = fp.customer_unique_id
),
cohort_size AS (
    SELECT

CREATE VIEW vw_delivery_review_correlation AS
SELECT 
    CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late'
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 'On-time or Early'
    END AS delivery_status,
    COUNT(*) AS num_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status;    