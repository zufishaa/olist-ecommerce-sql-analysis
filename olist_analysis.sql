SELECT COUNT(*) FROM orders;
-- 1a. Look at the first 10 orders
SELECT * FROM orders LIMIT 10;

-- 1b. What order statuses exist, and how many of each?
SELECT order_status, COUNT(*) AS num_orders
FROM orders
GROUP BY order_status
ORDER BY num_orders DESC;

-- Q1. How many delivered orders, customers and products?
SELECT
    COUNT(DISTINCT o.order_id)            AS total_orders,
    COUNT(DISTINCT c.customer_unique_id)  AS total_customers,
    COUNT(DISTINCT oi.product_id)         AS total_products
FROM orders o
JOIN customers c    ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';

-- Q2. Total revenue from delivered orders (product price, excluding delivery fees)
SELECT ROUND(SUM(oi.price), 2) AS total_revenue
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

-- 1b RESULT: 96,478 of 99,441 orders (97%) were delivered.
--   Only delivered orders are used for revenue analysis.

-- Q1 RESULT: 96,478 orders | 93,358 customers | 32,216 products

-- Q2 RESULT: Total revenue R$ 13,221,498 (product sales, excl. delivery fees)

-- Q3. Monthly revenue trend
SELECT
    strftime('%Y-%m', o.order_purchase_timestamp) AS month,
    COUNT(DISTINCT o.order_id)                    AS orders,
    ROUND(SUM(oi.price), 2)                       AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY month
ORDER BY month;
-- Q3 RESULT: Peak month Nov 2017 (7,289 orders, R$ 987,766), +63% orders vs Oct (Black Friday).
--   Monthly revenue roughly doubled Jul 2017 -> 2018, then plateaued at ~R$ 0.85-0.98M.
--   Note: 2016 and late 2018 are partial months at the edges of the dataset.

-- Q4. Top 10 product categories by revenue (English names)
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
    COUNT(DISTINCT o.order_id)  AS orders,
    ROUND(SUM(oi.price), 2)     AS revenue
FROM order_items oi
JOIN orders o                    ON oi.order_id = o.order_id
JOIN products p                  ON oi.product_id = p.product_id
LEFT JOIN category_translation t ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;

-- Q4 RESULT: Top category health_beauty (R$ 1.23M). watches_gifts is 2nd with fewer orders
--   but the highest value per order (~R$ 212 vs ~R$ 143). bed_bath_table has the most
--   orders (9,272) but low value (~R$ 110). Top 10 categories = ~62% of total revenue.

-- Q5. Customers and revenue by state (top 10)
SELECT
    c.customer_state                       AS state,
    COUNT(DISTINCT c.customer_unique_id)   AS customers,
    ROUND(SUM(oi.price), 2)                AS revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT c.customer_unique_id), 2) AS revenue_per_customer
FROM orders o
JOIN customers c    ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY state
ORDER BY revenue DESC
LIMIT 10;

-- Q5 RESULT: SP = 42% of customers and 38% of revenue (R$ 5.07M). Top 3 states
--   (SP, RJ, MG) = ~63% of revenue. SP has the LOWEST revenue per customer in the
--   top 10 (R$ 129); BA the highest (R$ 156), possibly because distant customers
--   buy fewer, higher-value items given longer delivery times and costs.

-- Q6. Payment methods: how often each is used and its share of orders
SELECT
    p.payment_type,
    COUNT(DISTINCT p.order_id) AS orders,
    ROUND(100.0 * COUNT(DISTINCT p.order_id) /
          (SELECT COUNT(DISTINCT order_id) FROM payments), 1) AS pct_of_orders,
    ROUND(AVG(p.payment_installments), 1) AS avg_installments
FROM payments p
GROUP BY p.payment_type
ORDER BY orders DESC;

-- Q6 RESULT: Credit card = 77% of orders (avg 3.5 instalments); boleto (bank slip) = 20%;
--   voucher 4%; debit card 1.5%. Percentages sum to >100% because some orders
--   combine methods (e.g. voucher + card).

-- Q11. Do late deliveries lead to worse reviews?
SELECT
    CASE
        WHEN date(o.order_delivered_customer_date) > date(o.order_estimated_delivery_date)
        THEN 'Late'
        ELSE 'On time'
    END                                            AS delivery_status,
    COUNT(DISTINCT o.order_id)                     AS orders,
    ROUND(AVG(CAST(r.review_score AS INTEGER)), 2) AS avg_review,
    ROUND(100.0 * SUM(CASE WHEN CAST(r.review_score AS INTEGER) <= 2 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                           AS pct_bad_reviews
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date <> ''
GROUP BY delivery_status;

-- Q11 RESULT: Late orders average 2.27 stars vs 4.29 for on-time orders.
--   62.4% of late orders receive a 1-2 star review vs 9.3% of on-time orders
--   (~7x more likely). Only ~7% of orders are late (6,381 of 95,824).
-- RECOMMENDATION: Reducing late deliveries (more accurate delivery estimates,
--   seller performance targets, proactive delay updates) is a key lever for
--   improving customer satisfaction.

-- Q7. Top 10 customers and their share of total revenue
WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS orders,
        SUM(oi.price)              AS revenue
    FROM orders o
    JOIN customers c    ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    orders,
    ROUND(revenue, 2) AS revenue,
    ROUND(100.0 * revenue / (SELECT SUM(revenue) FROM customer_revenue), 3) AS pct_of_total
FROM customer_revenue
ORDER BY revenue DESC
LIMIT 10;

-- Q7 RESULT: Top 10 customers = only ~0.5% of total revenue (~R$ 67.6k of R$ 13.2M).
--   9 of the top 10 ordered just once (top customer: R$ 13,440 in a single order).
--   Revenue is spread across many small one-off purchases, with no reliance on
--   a few high-value customers.

-- Q8. How many customers ordered more than once?
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS num_orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*)                                              AS total_customers,
    SUM(CASE WHEN num_orders > 1 THEN 1 ELSE 0 END)       AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN num_orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_repeat
FROM customer_orders;

-- Q8 RESULT: Only 3.0% of customers (2,801 of 93,358) made more than one purchase.
--   97% bought once and never returned -> a major retention problem. Revenue growth
--   depends almost entirely on acquiring new customers.

-- Q10. Customer segmentation (RFM)
WITH customer_stats AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase,
        COUNT(DISTINCT o.order_id)      AS frequency,
        SUM(oi.price)                   AS monetary
    FROM orders o
    JOIN customers c    ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm AS (
    SELECT *,
        ROUND(julianday((SELECT MAX(order_purchase_timestamp) FROM orders))
              - julianday(last_purchase)) AS recency_days
    FROM customer_stats
),
scores AS (
    SELECT *,
        NTILE(3) OVER (ORDER BY recency_days DESC) AS r_score,  -- 3 = most recent
        NTILE(3) OVER (ORDER BY monetary)          AS m_score   -- 3 = highest spend
    FROM rfm
),
segments AS (
    SELECT *,
        CASE
            WHEN frequency > 1                  THEN 'Repeat buyers'
            WHEN r_score = 3 AND m_score = 3    THEN 'High value - recent'
            WHEN r_score = 1 AND m_score = 3    THEN 'High value - at risk'
            WHEN r_score = 3                    THEN 'Recent - low/mid spend'
            WHEN r_score = 1                    THEN 'Lost - low/mid spend'
            ELSE 'Middle'
        END AS segment
    FROM scores
)
SELECT
    segment,
    COUNT(*)                                                        AS customers,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM segments), 1)    AS pct_customers,
    ROUND(AVG(monetary), 2)                                         AS avg_spend,
    ROUND(AVG(recency_days))                                        AS avg_days_since_purchase,
    ROUND(100.0 * SUM(monetary) / (SELECT SUM(monetary) FROM segments), 1) AS pct_revenue
FROM segments
GROUP BY segment
ORDER BY pct_revenue DESC;

-- Q10 RESULT: High-value segments = 21% of customers but 45% of revenue (avg ~R$ 300+).
--   'High value - at risk' (9,652 customers, avg R$ 310, last order ~467 days ago)
--   = 22.6% of revenue -> priority win-back target. Repeat buyers = 3% of customers
--   but spend ~2x the average (R$ 260). Low/mid spenders = 44% of customers, 19% of revenue.
-- RECOMMENDATIONS: (1) win-back campaign for high-value at-risk customers;
--   (2) encourage second purchases from recent high-value customers;
--   (3) reduce late deliveries to improve first experiences and retention.
