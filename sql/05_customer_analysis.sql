-- =========================================================
-- 05_customer_analysis.sql
--
-- Purpose:
-- Understand customer behavior at household level and identify
-- actionable customer segments based on value and engagement.
--
-- Main questions:
-- 1. How much do customers spend overall?
-- 2. How is customer value distributed?
-- 3. Is revenue concentrated in a smaller customer group?
-- 4. Can customers be split into meaningful behavioral segments?
-- 5. How do those segments differ in shopping behavior?
--
-- Important note:
-- The quantity field contains extreme outliers and is not used
-- as a primary metric. Analysis relies on:
-- - sales_value (monetary value)
-- - basket_id (frequency proxy)
-- - basket lines (behavior proxy)
-- - product variety
-- =========================================================



-- =========================================================
-- REUSABLE BLOCK 1: Customer metrics
--
-- Purpose:
-- Create a base customer-level dataset.
--
-- Grain:
-- 1 row = 1 household
--
-- Why this matters:
-- This ensures all downstream analysis operates at a consistent
-- and correct grain, avoiding distortion from transaction-level
-- duplication.
-- =========================================================

CREATE OR REPLACE VIEW vw_05_customer_metrics AS 
SELECT
    t.household_key,
    SUM(t.sales_value) AS total_spend,
    COUNT(DISTINCT t.basket_id) AS total_baskets,
    COUNT(*) AS total_basket_lines,
    COUNT(DISTINCT t.product_id) AS distinct_products_purchased,
    ROUND(SUM(t.sales_value) / COUNT(DISTINCT t.basket_id), 2) AS avg_basket_value,
    ROUND(COUNT(*)::numeric / COUNT(DISTINCT t.basket_id), 2) AS avg_lines_per_basket
FROM transaction_data AS t
GROUP BY t.household_key;



-- =========================================================
-- REUSABLE BLOCK 2: Segmentation thresholds
--
-- Purpose:
-- Define median thresholds for spend and frequency.
--
-- Why this matters:
-- Provides consistent and data-driven boundaries for
-- segmentation without hardcoding arbitrary values.
-- =========================================================

CREATE OR REPLACE VIEW vw_05_segment_thresholds AS
SELECT
    percentile_cont(0.5) WITHIN GROUP (ORDER BY total_spend) AS median_spend,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY total_baskets) AS median_baskets
FROM vw_05_customer_metrics;



-- =========================================================
-- REUSABLE BLOCK 3: Customer segmentation
--
-- Purpose:
-- Assign each household to a behavioral segment.
--
-- Segmentation logic:
-- - Spend: above/below median
-- - Frequency: above/below median
--
-- Output:
-- 4 segments:
-- - High Spend / High Frequency
-- - High Spend / Low Frequency
-- - Low Spend / High Frequency
-- - Low Spend / Low Frequency
-- =========================================================

CREATE OR REPLACE VIEW vw_05_segmented_customers AS
SELECT
    cm.household_key,
    cm.total_spend,
    cm.total_baskets,
    cm.total_basket_lines,
    cm.distinct_products_purchased,
    cm.avg_basket_value,
    cm.avg_lines_per_basket,
    CASE
        WHEN cm.total_spend > st.median_spend
         AND cm.total_baskets > st.median_baskets THEN 'High Spend / High Frequency'
        WHEN cm.total_spend > st.median_spend
         AND cm.total_baskets <= st.median_baskets THEN 'High Spend / Low Frequency'
        WHEN cm.total_spend <= st.median_spend
         AND cm.total_baskets > st.median_baskets THEN 'Low Spend / High Frequency'
        ELSE 'Low Spend / Low Frequency'
    END AS customer_segment
FROM vw_05_customer_metrics AS cm
CROSS JOIN vw_05_segment_thresholds AS st;



-- =========================================================
-- Section 1: Spend distribution across customers
--
-- Objective:
-- Understand overall customer value distribution and identify
-- skewness between average and high-value customers.
-- =========================================================

SELECT 
    COUNT(*) AS total_customers,
    SUM(total_spend) AS total_spend,
    AVG(total_spend) AS avg_total_spend,
    MIN(total_spend) AS min_customer_spend,
    MAX(total_spend) AS max_customer_spend,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY total_spend) AS median_spend,
    percentile_cont(0.9) WITHIN GROUP (ORDER BY total_spend) AS p90_spend,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY total_spend) AS p99_spend
FROM vw_05_customer_metrics;



-- =========================================================
-- Section 2: Revenue concentration
--
-- Objective:
-- Measure how much revenue is driven by top customers.
--
-- Why this matters:
-- Helps determine whether the business depends heavily on
-- a small group of high-value customers.
-- =========================================================

WITH ranked_customers AS (
    SELECT
        household_key,
        total_spend,
        ROW_NUMBER() OVER (ORDER BY total_spend DESC) AS spend_rank,
        COUNT(*) OVER () AS total_customers,
        SUM(total_spend) OVER () AS total_revenue
    FROM vw_05_customer_metrics
)

SELECT
    CASE
        WHEN spend_rank <= 0.01 * total_customers THEN 'Top 1%'
        WHEN spend_rank <= 0.05 * total_customers THEN 'Next 4%'
        WHEN spend_rank <= 0.10 * total_customers THEN 'Next 5%'
        WHEN spend_rank <= 0.20 * total_customers THEN 'Next 10%'
        ELSE 'Bottom 80%'
    END AS customer_segment,
    COUNT(*) AS customers_in_segment,
    SUM(total_spend) AS segment_revenue,
    ROUND(SUM(total_spend) / MAX(total_revenue) * 100, 2) AS revenue_share_percent
FROM ranked_customers
GROUP BY customer_segment
ORDER BY MIN(spend_rank);



-- =========================================================
-- Section 3: Segment profiling
--
-- Note:
-- Customer segmentation is defined in reusable views above.
-- This section profiles the resulting segments.
--
-- Objective:
-- Compare segments based on value, frequency, basket behavior,
-- and product diversity.
--
-- Grain:
-- 1 row = 1 household
-- =========================================================

SELECT
    customer_segment,
    COUNT(*) AS customers_in_segment,
    ROUND(AVG(total_spend), 2) AS avg_customer_spend,
    ROUND(AVG(total_baskets), 2) AS avg_customer_baskets,
    ROUND(AVG(avg_basket_value), 2) AS avg_basket_value,
    ROUND(AVG(avg_lines_per_basket), 2) AS avg_lines_per_basket,
    ROUND(AVG(distinct_products_purchased), 2) AS avg_distinct_products,
    ROUND(SUM(total_spend), 2) AS total_segment_revenue,
    ROUND(
        SUM(total_spend) * 100.0 / SUM(SUM(total_spend)) OVER (),
        2
    ) AS revenue_share_percent
FROM vw_05_segmented_customers
GROUP BY customer_segment
ORDER BY total_segment_revenue DESC;



-- =========================================================
-- Section 4: Segment interpretation
--
-- Objective:
-- Translate segment-level behavior into business strategy.
-- =========================================================

-- Core segment: High Spend / High Frequency (~75.8%)
-- These customers generate the majority of revenue and show
-- strong engagement. This is the primary business driver.
-- Action: Focus on retention, loyalty programs, and maintaining
-- high engagement to prevent churn.

-- Growth segment: High Spend / Low Frequency (~8.5%)
-- These customers show the highest basket value but lower visit
-- frequency. They represent high potential revenue growth.
-- Action: Increase visit frequency through targeted promotions
-- and personalized engagement.

-- Basket expansion segment: Low Spend / High Frequency (~4%)
-- These customers shop often but spend less per visit.
-- Action: Increase basket size through cross-sell, upsell,
-- and bundling strategies.

-- Low-priority segment: Low Spend / Low Frequency (~11.7%)
-- These customers contribute relatively little revenue and show
-- low engagement.
-- Action: Manage efficiently with low-cost, broad marketing.