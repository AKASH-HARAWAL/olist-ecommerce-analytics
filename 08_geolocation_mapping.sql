-- ============================================================
-- GEOLOCATION PREP FOR MAPPING
-- Aggregates customer locations and delivery performance by 
-- zip code prefix, for use in a Power BI map visual.
-- ============================================================

SELECT 
    c.customer_zip_code_prefix,
    g.geolocation_lat,
    g.geolocation_lng,
    g.geolocation_city,
    g.geolocation_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(
        SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0 
        / COUNT(DISTINCT o.order_id), 2
    ) AS late_delivery_pct
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
JOIN (
    -- One representative lat/lng per zip prefix (avoids duplicate map points)
    SELECT DISTINCT ON (geolocation_zip_code_prefix) 
        geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state
    FROM geolocation
) g ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE o.order_status = 'delivered'
GROUP BY c.customer_zip_code_prefix, g.geolocation_lat, g.geolocation_lng, g.geolocation_city, g.geolocation_state
HAVING COUNT(DISTINCT o.order_id) >= 5  -- filter out near-empty zip codes for cleaner map
ORDER BY total_orders DESC;