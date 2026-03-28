-- =========================================================
-- 08_campaign_analysis.sql
--
-- Purpose:
-- Evaluate campaign performance by comparing campaign reach,
-- coupon volume, and redemption behavior to understand
-- how campaigns perform across the customer base.
--
-- Main questions:
-- 1. How large is each campaign in terms of targeted households?
-- 2. How many coupons are linked to each campaign?
-- 3. How much redemption activity does each campaign generate?
-- 4. Which customer segments respond most strongly to campaigns?
--
-- Note:
-- This section measures matched campaign-linked redemption
-- behavior, not causal uplift. Redemption does not prove
-- that the campaign changed customer behavior.

-- Limitation:
-- Coupon UPC is not unique to campaign, so campaign-level redemption
-- attribution is approximate and should be interpreted directionally.
-- =========================================================


-- =========================================================
-- REUSABLE BLOCK: Campaign metrics
--
-- Purpose:
-- Create a reusable campaign-level view showing how many
-- households were targeted, how many coupons were linked,
-- and how much matched redemption activity each campaign generated.
--
-- Grain:
-- 1 row = 1 campaign
--
-- Business meaning:
-- This view summarizes campaign size and observed redemption
-- activity. It supports campaign-level comparison, but should
-- be interpreted directionally rather than as precise causal
-- performance.
-- =========================================================
CREATE OR REPLACE VIEW vw_08_campaign_metrics AS
WITH campaign_household_coupon_links AS (
    SELECT DISTINCT
        ct.campaign,
        ct.household_key,
        c.coupon_upc,
        CASE
            WHEN cr.coupon_upc IS NOT NULL THEN 1
            ELSE 0
        END AS was_redeemed
    FROM campaign_table AS ct
    JOIN coupon AS c
        ON ct.campaign = c.campaign
    LEFT JOIN coupon_redempt AS cr
        ON ct.household_key = cr.household_key
       AND c.coupon_upc = cr.coupon_upc
)

SELECT
    campaign,
    COUNT(DISTINCT household_key) AS households_targeted,
    COUNT(DISTINCT coupon_upc) AS total_linked_coupons,
    COUNT(DISTINCT CASE
        WHEN was_redeemed = 1 THEN (household_key, coupon_upc)
    END) AS total_redeemed_coupons
FROM campaign_household_coupon_links
GROUP BY campaign;


-- =========================================================
-- REUSABLE BLOCK: Campaign metrics by customer segment
--
-- Purpose:
-- Create a reusable campaign-segment view showing how many
-- households were targeted in each segment and how much
-- redemption activity came from those households.
--
-- Grain:
-- 1 row = 1 campaign + 1 customer segment
--
-- Business meaning:
-- This view shows whether campaigns are engaging a broad
-- customer base or mainly reinforcing behavior among already
-- valuable customer segments.
-- =========================================================
CREATE OR REPLACE VIEW vw_08_campaign_segment_metrics AS
WITH campaign_segment_base AS (
    SELECT
        ct.campaign,
        sc.customer_segment,
        ct.household_key,
        c.coupon_upc,
        CASE
            WHEN cr.coupon_upc IS NOT NULL THEN 1
            ELSE 0
        END AS was_redeemed
    FROM campaign_table AS ct
    JOIN coupon AS c
        ON ct.campaign = c.campaign
    LEFT JOIN coupon_redempt AS cr
        ON ct.household_key = cr.household_key
       AND c.coupon_upc = cr.coupon_upc
    JOIN vw_05_segmented_customers AS sc
        ON ct.household_key = sc.household_key
)

SELECT
    campaign,
    customer_segment,
    COUNT(DISTINCT household_key) AS households_targeted,
    COUNT(DISTINCT CASE
        WHEN was_redeemed = 1 THEN (household_key, coupon_upc)
    END) AS total_redeemed_coupons,
    COUNT(DISTINCT CASE
        WHEN was_redeemed = 1 THEN household_key
    END) AS households_with_redemption,
    ROUND(
        COUNT(DISTINCT CASE
            WHEN was_redeemed = 1 THEN household_key
        END)::numeric
        / COUNT(DISTINCT household_key) * 100,
        2
    ) AS participation_rate,
    ROUND(
        COUNT(DISTINCT CASE
            WHEN was_redeemed = 1 THEN (household_key, coupon_upc)
        END)::numeric
        / COUNT(DISTINCT household_key),
        2
    ) AS redemptions_per_household
FROM campaign_segment_base
GROUP BY campaign, customer_segment;


-- =========================================================
-- Section 1: Campaign performance overview
--
-- Task:
-- Compare campaign scale and redemption activity across campaigns.
--
-- Note:
-- Redemptions are matched household-coupon redemption events,
-- not causal uplift.
-- =========================================================
SELECT
    campaign,
    households_targeted,
    total_linked_coupons,
    total_redeemed_coupons,
    ROUND(
        total_redeemed_coupons::numeric
        / NULLIF(households_targeted, 0),
        2
    ) AS redemptions_per_targeted_household
FROM vw_08_campaign_metrics
ORDER BY total_redeemed_coupons DESC;

-- Summary:
-- Large campaigns drive the highest total redemption volume, but
-- efficiency varies, so campaign size alone does not explain performance.

-- Analyst explanation:
-- Campaigns 18 and 13 combine high reach with relatively strong redemption
-- intensity, while other large campaigns such as campaign 8 generate weaker
-- redemption per targeted household. This suggests that campaign results
-- depend not only on scale, but also on targeting quality and offer relevance.

-- Business implication:
-- Campaign strategy should not be judged on reach alone. Large campaigns can
-- generate volume, but weaker redemption intensity may signal inefficient
-- targeting or lower offer relevance. Stronger campaigns should be studied
-- for repeatable patterns, while weaker ones should be reviewed and improved.


-- =========================================================
-- Section 2: Campaign behavior by customer segment
--
-- Task:
-- Compare campaign reach and redemption behavior across
-- customer segments.
--
-- Note:
-- This section shows whether campaign engagement is broadly
-- distributed across the customer base or concentrated in
-- specific customer segments.
-- =========================================================
SELECT
    campaign,
    customer_segment,
    households_targeted,
    total_redeemed_coupons,
    households_with_redemption,
    participation_rate,
    redemptions_per_household
FROM vw_08_campaign_segment_metrics
ORDER BY campaign, total_redeemed_coupons DESC;

-- Summary:
-- Campaign engagement is heavily concentrated in high-value customer
-- segments, especially High Spend / High Frequency households, while
-- low-value segments show minimal participation across most campaigns.

-- Analyst explanation:
-- High Spend / High Frequency customers consistently generate the strongest
-- participation and redemption volume across campaigns. In contrast, weaker
-- segments are either lightly targeted or show very limited response when
-- included. This suggests that campaign activity is primarily reinforcing
-- existing behavior rather than activating less engaged customers.

-- Business implication:
-- The current campaign strategy appears stronger for retention than for growth.
-- Marketing effort is concentrated on already valuable customers, while lower-
-- value segments remain largely inactive. If the business wants broader customer
-- development, future campaigns should test more targeted approaches for
-- mid-potential and under-engaged segments.