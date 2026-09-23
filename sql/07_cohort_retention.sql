-- ============================================================
-- COHORT RETENTION ANALYSIS
-- Groups customers by their first purchase month (cohort), then
-- tracks what % of each cohort returned to purchase in later months.
-- ============================================================

WITH customer_orders AS (
    -- One row per customer per order, using customer_unique_id 
    -- to correctly identify repeat customers across orders
    SELECT 
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
first_purchase AS (
    -- Each customer's first-ever purchase month = their cohort
    SELECT 
        customer_unique_id,
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS cohort_month
    FROM customer_orders
    GROUP BY customer_unique_id
),
customer_activity AS (
    -- Every purchase month for every customer, tagged with their cohort
    SELECT 
        co.customer_unique_id,
        fp.cohort_month,
        DATE_TRUNC('month', co.order_purchase_timestamp) AS activity_month,
        -- Months since first purchase (0 = same month as first purchase)
        (DATE_PART('year', DATE_TRUNC('month', co.order_purchase_timestamp)) - DATE_PART('year', fp.cohort_month)) * 12 +
        (DATE_PART('month', DATE_TRUNC('month', co.order_purchase_timestamp)) - DATE_PART('month', fp.cohort_month)) AS months_since_first_purchase
    FROM customer_orders co
    JOIN first_purchase fp ON co.customer_unique_id = fp.customer_unique_id
),
cohort_size AS (
    -- Total number of customers in each cohort (month 0 count)
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