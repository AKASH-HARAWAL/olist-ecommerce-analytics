-- ============================================================
-- OPERATIONS & DELIVERY ANALYSIS
-- Investigates delivery performance, identifies late-delivery
-- patterns, and connects delivery timing to customer review scores.
-- ============================================================

-- Query 1: Overall delivery performance summary
-- Compares actual delivery time vs estimated delivery time
SELECT 
    COUNT(*) AS total_delivered_orders,
    ROUND(AVG(EXTRACT(DAY FROM (order_delivered_customer_date - order_purchase_timestamp))), 2) AS avg_actual_delivery_days,
    ROUND(AVG(EXTRACT(DAY FROM (order_estimated_delivery_date - order_purchase_timestamp))), 2) AS avg_estimated_delivery_days,
    ROUND(AVG(EXTRACT(DAY FROM (order_delivered_customer_date - order_estimated_delivery_date))), 2) AS avg_delay_days
FROM orders
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL;

-- INSIGHT: Average delivery beats estimate by ~11 days (avg_delay_days = -10.96).
-- However, this average can mask a smaller group of genuinely late orders,
-- so we check the distribution next rather than trusting the average alone.


-- Query 2: Delivery status distribution (late vs on-time/early)
-- Breaks the average down into actual counts, to check for hidden skew
SELECT 
    CASE 
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'On-time or Early'
    END AS delivery_status,
    COUNT(*) AS num_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM orders
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status;

-- INSIGHT: 8.11% of orders (7,826) were genuinely late, despite the 
-- reassuring average. This late segment is the real risk group to investigate.


-- Query 3: Delivery status vs average review score (KEY INSIGHT)
-- Connects operational performance (delivery timing) to customer 
-- experience outcome (review score)
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

-- KEY INSIGHT: Late orders average 2.57 stars vs 4.29 for on-time/early —
-- a 1.72-star (40%) gap. Late delivery is a major driver of poor reviews,
-- despite representing only 8.11% of total order volume.


-- Query 4: Late delivery rate and review score by customer state
-- Identifies which regions to prioritize for logistics improvement
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
HAVING COUNT(*) >= 50  -- exclude states with too few orders to be statistically meaningful
ORDER BY late_delivery_pct DESC;

-- FINAL INSIGHT: Late delivery rates range from 2.89% (RO) to 23.37% (AL),
-- with Northeastern states (AL, MA, PI, CE, SE) consistently underperforming.
-- Notably, Rio de Janeiro (RJ) — a top-5 volume state — shows a 13.30% late
-- rate, more than double São Paulo's 5.82%, despite comparable logistics
-- infrastructure. This points to a specific operational gap in RJ worth
-- investigating, rather than a simple remoteness/geography explanation.
-- RECOMMENDATION: Prioritize carrier/logistics review in RJ and the
-- Northeastern states identified above.