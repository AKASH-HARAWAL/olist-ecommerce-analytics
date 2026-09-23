-- ============================================================
-- CUSTOMER LIFETIME VALUE (CLV) ESTIMATION
-- Simple, explainable CLV model: 
-- CLV = Avg Order Value × Purchase Frequency × Estimated Customer Lifespan
-- ============================================================

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
customer_metrics AS (
    SELECT 
        customer_unique_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(payment_value) AS total_spend,
        ROUND(AVG(payment_value), 2) AS avg_order_value,
        MIN(order_purchase_timestamp) AS first_purchase,
        MAX(order_purchase_timestamp) AS last_purchase
    FROM customer_orders
    GROUP BY customer_unique_id
),
overall_stats AS (
    -- Platform-wide averages, used to fill in for customers with only 1 order
    -- (can't calculate a real "lifespan" from a single data point)
    SELECT 
        AVG(total_orders) AS avg_platform_orders,
        AVG(avg_order_value) AS avg_platform_order_value
    FROM customer_metrics
)
SELECT 
    cm.customer_unique_id,
    cm.total_orders,
    cm.avg_order_value,
    cm.total_spend AS historical_spend,
    -- Simplified CLV: avg order value x total orders (historical) 
    -- as a conservative baseline, since most customers are one-time buyers
    -- (per our cohort analysis finding)
    ROUND(cm.avg_order_value * cm.total_orders, 2) AS clv_historical,
    -- Segment customers by CLV tier for actionable grouping
    CASE 
        WHEN cm.total_spend >= 1000 THEN 'High Value'
        WHEN cm.total_spend >= 300 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS clv_tier
FROM customer_metrics cm
ORDER BY clv_historical DESC
LIMIT 20;

-- CLV tier distribution summary
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
GROUP BY clv_tier
ORDER BY avg_spend DESC;