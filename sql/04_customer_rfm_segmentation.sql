-- RFM (Recency, Frequency, Monetary) Customer Segmentation
-- Segments customers into Champions, Loyal, At Risk, Lost, New, and Needs Attention
-- based on NTILE(5) scoring across all three dimensions.
-- Uses customer_unique_id (not customer_id) since Olist assigns a new 
-- customer_id per order, which would otherwise misrepresent repeat customers.

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
),
rfm_segmented AS (
    SELECT *,
        CASE 
            WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
            WHEN recency_score >= 3 AND frequency_score >= 3 THEN 'Loyal Customers'
            WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'New Customers'
            WHEN recency_score <= 2 AND frequency_score >= 3 THEN 'At Risk'
            WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'Lost'
            ELSE 'Needs Attention'
        END AS customer_segment
    FROM rfm_scored
)
SELECT customer_segment, COUNT(*) AS num_customers, ROUND(AVG(monetary),2) AS avg_spend
FROM rfm_segmented
GROUP BY customer_segment
ORDER BY num_customers DESC;