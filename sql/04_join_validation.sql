-- =========================================================
-- 04_join_validation.sql
-- Purpose:
-- Check the main joins we will rely on later in the project.
--
-- Why this file exists:
-- Before doing customer, coupon, and campaign analysis,
-- we want to make sure the important tables connect the way
-- we expect.
--
-- Main things we care about:
-- 1. Can transactions join to products?
-- 2. How many transaction households have demographics?
-- 3. Can coupon redemptions map back to coupon definitions?
-- 4. Do campaign-related tables use valid campaign IDs?
-- =========================================================


-- ---------------------------------------------------------
-- 1) transaction_data -> product
-- Check if transaction products exist in the product table.
--
-- Why this matters:
-- If this join is weak, product and category analysis will be
-- incomplete or misleading.
-- ---------------------------------------------------------

WITH transaction_products AS (
    SELECT DISTINCT product_id
    FROM transaction_data
),
matched_products AS (
    SELECT DISTINCT t.product_id
    FROM transaction_data AS t
    JOIN product AS p
        ON t.product_id = p.product_id
),
missing_products AS (
    SELECT DISTINCT t.product_id
    FROM transaction_data AS t
    LEFT JOIN product AS p
        ON t.product_id = p.product_id
    WHERE p.product_id IS NULL
)
SELECT
    'transaction_data -> product' AS join_name,
    (SELECT COUNT(*) FROM transaction_products) AS left_distinct_keys,
    (SELECT COUNT(*) FROM matched_products) AS matched_distinct_keys,
    (SELECT COUNT(*) FROM missing_products) AS unmatched_distinct_keys,
    ROUND(
        100.0 * (SELECT COUNT(*) FROM matched_products)
        / NULLIF((SELECT COUNT(*) FROM transaction_products), 0),
        2
    ) AS match_rate_pct;


-- ---------------------------------------------------------
-- 2) transaction_data -> hh_demographic
-- Check how many transaction households have demographic data.
--
-- Why this matters:
-- Later, if we segment customers by age, income, or household
-- type, that analysis will only cover the matched subset.
-- ---------------------------------------------------------

WITH transaction_households AS (
    SELECT DISTINCT household_key
    FROM transaction_data
),
matched_households AS (
    SELECT DISTINCT t.household_key
    FROM transaction_data AS t
    JOIN hh_demographic AS h
        ON t.household_key = h.household_key
),
missing_households AS (
    SELECT DISTINCT t.household_key
    FROM transaction_data AS t
    LEFT JOIN hh_demographic AS h
        ON t.household_key = h.household_key
    WHERE h.household_key IS NULL
)
SELECT
    'transaction_data -> hh_demographic' AS join_name,
    (SELECT COUNT(*) FROM transaction_households) AS left_distinct_keys,
    (SELECT COUNT(*) FROM matched_households) AS matched_distinct_keys,
    (SELECT COUNT(*) FROM missing_households) AS unmatched_distinct_keys,
    ROUND(
        100.0 * (SELECT COUNT(*) FROM matched_households)
        / NULLIF((SELECT COUNT(*) FROM transaction_households), 0),
        2
    ) AS match_rate_pct;


-- ---------------------------------------------------------
-- 3) coupon_redempt -> coupon
-- Check if redeemed coupon UPCs exist in the coupon table.
--
-- Why this matters:
-- We need this join if we want to connect redemption events
-- to coupon details, products, and campaigns.
-- ---------------------------------------------------------

WITH redeemed_coupons AS (
    SELECT DISTINCT coupon_upc
    FROM coupon_redempt
),
matched_coupons AS (
    SELECT DISTINCT cr.coupon_upc
    FROM coupon_redempt AS cr
    JOIN coupon AS c
        ON cr.coupon_upc = c.coupon_upc
),
missing_coupons AS (
    SELECT DISTINCT cr.coupon_upc
    FROM coupon_redempt AS cr
    LEFT JOIN coupon AS c
        ON cr.coupon_upc = c.coupon_upc
    WHERE c.coupon_upc IS NULL
)
SELECT
    'coupon_redempt -> coupon' AS join_name,
    (SELECT COUNT(*) FROM redeemed_coupons) AS left_distinct_keys,
    (SELECT COUNT(*) FROM matched_coupons) AS matched_distinct_keys,
    (SELECT COUNT(*) FROM missing_coupons) AS unmatched_distinct_keys,
    ROUND(
        100.0 * (SELECT COUNT(*) FROM matched_coupons)
        / NULLIF((SELECT COUNT(*) FROM redeemed_coupons), 0),
        2
    ) AS match_rate_pct;


-- ---------------------------------------------------------
-- 4) coupon -> product
-- Check if coupon-linked products exist in the product table.
--
-- Why this matters:
-- If this join works well, we can analyze coupons by product,
-- brand, department, and category.
-- ---------------------------------------------------------

WITH coupon_products AS (
    SELECT DISTINCT product_id
    FROM coupon
),
matched_coupon_products AS (
    SELECT DISTINCT c.product_id
    FROM coupon AS c
    JOIN product AS p
        ON c.product_id = p.product_id
),
missing_coupon_products AS (
    SELECT DISTINCT c.product_id
    FROM coupon AS c
    LEFT JOIN product AS p
        ON c.product_id = p.product_id
    WHERE p.product_id IS NULL
)
SELECT
    'coupon -> product' AS join_name,
    (SELECT COUNT(*) FROM coupon_products) AS left_distinct_keys,
    (SELECT COUNT(*) FROM matched_coupon_products) AS matched_distinct_keys,
    (SELECT COUNT(*) FROM missing_coupon_products) AS unmatched_distinct_keys,
    ROUND(
        100.0 * (SELECT COUNT(*) FROM matched_coupon_products)
        / NULLIF((SELECT COUNT(*) FROM coupon_products), 0),
        2
    ) AS match_rate_pct;


-- ---------------------------------------------------------
-- 5) campaign_table -> campaign_desc
-- Check if campaign exposure rows map to valid campaigns.
--
-- Why this matters:
-- If this join is clean, campaign participation analysis will
-- have a reliable campaign lookup.
-- ---------------------------------------------------------

WITH campaign_table_campaigns AS (
    SELECT DISTINCT campaign
    FROM campaign_table
),
matched_campaigns AS (
    SELECT DISTINCT ct.campaign
    FROM campaign_table AS ct
    JOIN campaign_desc AS cd
        ON ct.campaign = cd.campaign
),
missing_campaigns AS (
    SELECT DISTINCT ct.campaign
    FROM campaign_table AS ct
    LEFT JOIN campaign_desc AS cd
        ON ct.campaign = cd.campaign
    WHERE cd.campaign IS NULL
)
SELECT
    'campaign_table -> campaign_desc' AS join_name,
    (SELECT COUNT(*) FROM campaign_table_campaigns) AS left_distinct_keys,
    (SELECT COUNT(*) FROM matched_campaigns) AS matched_distinct_keys,
    (SELECT COUNT(*) FROM missing_campaigns) AS unmatched_distinct_keys,
    ROUND(
        100.0 * (SELECT COUNT(*) FROM matched_campaigns)
        / NULLIF((SELECT COUNT(*) FROM campaign_table_campaigns), 0),
        2
    ) AS match_rate_pct;


-- ---------------------------------------------------------
-- 6) coupon -> campaign_desc
-- Check if coupon campaigns exist in the campaign master.
--
-- Why this matters:
-- This tells us whether coupon records can be safely tied to
-- campaign metadata.
-- ---------------------------------------------------------

WITH coupon_campaigns AS (
    SELECT DISTINCT campaign
    FROM coupon
),
matched_coupon_campaigns AS (
    SELECT DISTINCT c.campaign
    FROM coupon AS c
    JOIN campaign_desc AS cd
        ON c.campaign = cd.campaign
),
missing_coupon_campaigns AS (
    SELECT DISTINCT c.campaign
    FROM coupon AS c
    LEFT JOIN campaign_desc AS cd
        ON c.campaign = cd.campaign
    WHERE cd.campaign IS NULL
)
SELECT
    'coupon -> campaign_desc' AS join_name,
    (SELECT COUNT(*) FROM coupon_campaigns) AS left_distinct_keys,
    (SELECT COUNT(*) FROM matched_coupon_campaigns) AS matched_distinct_keys,
    (SELECT COUNT(*) FROM missing_coupon_campaigns) AS unmatched_distinct_keys,
    ROUND(
        100.0 * (SELECT COUNT(*) FROM matched_coupon_campaigns)
        / NULLIF((SELECT COUNT(*) FROM coupon_campaigns), 0),
        2
    ) AS match_rate_pct;


-- ---------------------------------------------------------
-- 7) simple row count check after joins
-- This is a quick safety check.
--
-- Why this matters:
-- If row counts suddenly grow after a join, that can be a sign
-- of duplication or a many-to-many problem.
-- ---------------------------------------------------------


SELECT
    'transaction_data base rows' AS check_name,
    COUNT(*) AS row_count
FROM transaction_data

UNION ALL

SELECT
    'transaction_data joined to product' AS check_name,
    COUNT(*) AS row_count
FROM transaction_data AS t
JOIN product AS p
    ON t.product_id = p.product_id

UNION ALL

SELECT
    'transaction_data joined to hh_demographic' AS check_name,
    COUNT(*) AS row_count
FROM transaction_data AS t
JOIN hh_demographic AS h
    ON t.household_key = h.household_key;