-- =========================================================
-- 06_product_analysis.sql
--
-- Purpose:
-- Identify which products and categories drive revenue and
-- how they relate to basket size and overall business performance.
--
-- Decision:
-- Which products and categories should be prioritized in
-- assortment, promotion, and merchandising strategy.
-- =========================================================



-- =========================================================
-- REUSABLE BLOCK: Product metrics foundation
--
-- Purpose:
-- Create a reusable product-level performance layer that combines
-- product attributes with core commercial metrics.
--
-- Business meaning:
-- This view provides a single consistent product grain for all
-- later analysis blocks. It prevents transaction-level distortion
-- and allows fair comparison across products.
-- =========================================================
CREATE OR REPLACE VIEW vw_06_product_metrics AS
WITH total_baskets AS (
    SELECT COUNT(DISTINCT basket_id) AS total_basket_count
    FROM transaction_data
)
SELECT
    p.product_id,
    p.department,
    p.commodity_desc,
    p.brand,
    COUNT(*) AS transaction_count,
    SUM(td.sales_value) AS total_revenue,
    COUNT(DISTINCT td.basket_id) AS distinct_baskets,
    ROUND(
        COUNT(DISTINCT td.basket_id)::numeric
        / tb.total_basket_count,
        4
    ) AS basket_penetration
FROM transaction_data AS td
JOIN product AS p
    ON td.product_id = p.product_id
CROSS JOIN total_baskets AS tb
GROUP BY
    p.product_id,
    p.department,
    p.commodity_desc,
    p.brand,
    tb.total_basket_count;



-- =========================================================
-- Section 1: Products associated with larger baskets
--
-- Task:
-- Compare product-level basket size with the store average
-- and identify products linked to larger shopping trips.
--
-- Important interpretation note:
-- This block shows association, not causation.
-- It does NOT prove that a product causes baskets to become larger.
-- It only shows that the product tends to appear in larger baskets.
-- =========================================================
WITH basket_sizes AS (
    SELECT
        basket_id,
        COUNT(*) AS basket_size
    FROM transaction_data
    GROUP BY basket_id
),
avg_basket AS (
    SELECT
        AVG(basket_size::numeric) AS overall_avg_basket_size
    FROM basket_sizes
),
product_basket_pairs AS (
    SELECT DISTINCT
        product_id,
        basket_id
    FROM transaction_data
),
product_basket_behavior AS (
    SELECT
        pm.product_id,
        pm.commodity_desc,
        pm.brand,
        pm.distinct_baskets,
        pm.total_revenue,
        AVG(bs.basket_size::numeric) AS avg_basket_size
    FROM product_basket_pairs AS pbp
    JOIN basket_sizes AS bs
        ON pbp.basket_id = bs.basket_id
    JOIN vw_06_product_metrics AS pm
        ON pbp.product_id = pm.product_id
    WHERE pm.distinct_baskets >= 1000
    GROUP BY
        pm.product_id,
        pm.commodity_desc,
        pm.brand,
        pm.distinct_baskets,
        pm.total_revenue
)

SELECT
    pbb.product_id,
    pbb.commodity_desc,
    pbb.brand,
    ROUND(pbb.avg_basket_size, 2) AS avg_basket_size,
    ROUND(ab.overall_avg_basket_size, 2) AS overall_avg_basket_size,
    ROUND(
        ((pbb.avg_basket_size / ab.overall_avg_basket_size) - 1) * 100,
        2
    ) AS basket_size_pct_vs_avg
FROM product_basket_behavior AS pbb
CROSS JOIN avg_basket AS ab
ORDER BY basket_size_pct_vs_avg DESC
LIMIT 10;

-- Summary:
-- Some products are strongly associated with significantly larger baskets (3–4x above average).

-- Analyst explanation:
-- Top products in this list consistently appear in baskets with 30+ items,
-- compared to the overall average of ~9 items. These products are linked
-- to large shopping trips rather than small or convenience purchases.

-- Business implication:
-- These products can help identify high-value shopping missions and may be
-- useful candidates for cross-selling or bundling strategies linked to
-- larger basket trips.



-- =========================================================
-- Section 2: Product revenue concentration (Pareto view)
--
-- Task:
-- Rank products by revenue and measure how revenue accumulates
-- across top products.
--
-- Important note:
-- Non-sellable categories such as COUPON/MISC ITEMS are excluded
-- before ranking and cumulative calculations to avoid distortion.
-- =========================================================
WITH filtered_products AS (
    SELECT
        product_id,
        commodity_desc,
        brand,
        total_revenue
    FROM vw_06_product_metrics
    WHERE commodity_desc NOT IN ('COUPON/MISC ITEMS')
),
ranked_products AS (
    SELECT
        product_id,
        commodity_desc,
        brand,
        total_revenue,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        COUNT(*) OVER () AS total_products,
        SUM(total_revenue) OVER () AS total_revenue_all_products
    FROM filtered_products
),
cumulative_revenue AS (
    SELECT
        product_id,
        commodity_desc,
        brand,
        total_revenue,
        revenue_rank,
        total_products,
        total_revenue_all_products,
        SUM(total_revenue) OVER (
            ORDER BY revenue_rank
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue
    FROM ranked_products
)

SELECT
    product_id,
    commodity_desc,
    brand,
    ROUND(total_revenue, 2) AS total_revenue,
    revenue_rank,
    ROUND(
        cumulative_revenue / total_revenue_all_products * 100,
        2
    ) AS cumulative_revenue_pct
FROM cumulative_revenue
ORDER BY revenue_rank
LIMIT 10;

-- Summary:
-- Revenue is highly fragmented at product level.

-- Analyst explanation:
-- Revenue accumulates slowly at product level, showing that no small group
-- of individual products dominates sales. Even when expanding the view to
-- more top-ranked products, revenue remains broadly distributed.

-- Business implication:
-- The business cannot rely on a few key SKUs. Revenue depends on a broad
-- assortment, so availability and assortment depth are critical.



-- =========================================================
-- Section 3: Category revenue concentration (Pareto view)
--
-- Task:
-- Aggregate revenue at category level and measure concentration
-- across top categories.
--
-- Important note:
-- Non-sellable categories such as COUPON/MISC ITEMS are excluded
-- before ranking and cumulative calculations to avoid distortion.
-- =========================================================
WITH filtered_categories AS (
    SELECT
        commodity_desc,
        SUM(total_revenue) AS category_revenue
    FROM vw_06_product_metrics
    WHERE commodity_desc NOT IN ('COUPON/MISC ITEMS')
    GROUP BY commodity_desc
),
ranked_categories AS (
    SELECT
        commodity_desc,
        category_revenue,
        ROW_NUMBER() OVER (ORDER BY category_revenue DESC) AS revenue_rank,
        COUNT(*) OVER () AS total_categories,
        SUM(category_revenue) OVER () AS total_revenue_all_categories
    FROM filtered_categories
),
cumulative_revenue AS (
    SELECT
        commodity_desc,
        category_revenue,
        revenue_rank,
        total_categories,
        total_revenue_all_categories,
        SUM(category_revenue) OVER (
            ORDER BY revenue_rank
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue
    FROM ranked_categories
)

SELECT
    commodity_desc,
    ROUND(category_revenue, 2) AS category_revenue,
    revenue_rank,
    ROUND(
        cumulative_revenue / total_revenue_all_categories * 100,
        2
    ) AS cumulative_revenue_pct
FROM cumulative_revenue
ORDER BY revenue_rank
LIMIT 10;

-- Summary:
-- Revenue is much more concentrated at category level than at product level.

-- Analyst explanation:
-- Top categories such as soft drinks, beef, and dairy contribute a
-- significantly larger share of total revenue compared to individual products.
-- The cumulative curve rises faster, showing clearer concentration.

-- Business implication:
-- Strategic decisions should focus on category-level optimization first,
-- as categories — not individual SKUs — are the true revenue drivers.