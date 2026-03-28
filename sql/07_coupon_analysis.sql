-- =========================================================
-- 07_coupon_analysis.sql
--
-- Purpose:
-- Evaluate campaign-linked coupon opportunity and actual
-- redemption behavior at household level to understand
-- promotion engagement.
--
-- Main questions:
-- 1. How much campaign-linked coupon opportunity does each household have?
-- 2. How many coupons do households actually redeem?
-- 3. How large is the gap between coupon opportunity and actual usage?
--
-- Note:
-- This section measures campaign-linked coupon opportunity
-- and confirmed redemption behavior, not causal uplift.
-- Redemption does not prove that the coupon changed
-- customer behavior.
-- =========================================================


-- =========================================================
-- REUSABLE BLOCK: Coupon opportunity metrics per household
--
-- Purpose:
-- Create a reusable household-level view showing how many
-- campaigns each household was assigned to and how many
-- distinct coupon UPCs were linked to those campaigns.
--
-- Grain:
-- 1 row = 1 household
--
-- Business meaning:
-- This view measures structural coupon opportunity, not
-- confirmed coupon receipt. It reflects the scale of
-- campaign-linked coupon exposure available to each household.
-- =========================================================
CREATE OR REPLACE VIEW vw_07_coupon_opportunity_metrics AS
WITH household_campaign_coupon_links AS (
    SELECT DISTINCT
        ct.household_key,
        ct.campaign,
        c.coupon_upc
    FROM campaign_table AS ct
    JOIN coupon AS c
        ON ct.campaign = c.campaign
)

SELECT
    household_key,
    COUNT(DISTINCT campaign) AS total_campaigns_assigned,
    COUNT(DISTINCT coupon_upc) AS total_campaign_linked_coupons
FROM household_campaign_coupon_links
GROUP BY household_key;

-- =========================================================
-- REUSABLE BLOCK: Coupon redemption metrics per household
--
-- Purpose:
-- Create a reusable household-level view showing how many
-- distinct coupons each household actually redeemed.
--
-- Grain:
-- 1 row = 1 household
--
-- Business meaning:
-- This view measures actual coupon usage behavior. Unlike
-- campaign-linked coupon opportunity, it reflects confirmed
-- redemption activity and can be used to compare real
-- promotion engagement across households.
-- =========================================================
CREATE OR REPLACE VIEW vw_07_coupon_redemption_metrics AS
SELECT
    household_key,
    COUNT(DISTINCT coupon_upc) AS total_redeemed_coupons
FROM coupon_redempt
GROUP BY household_key;


-- =========================================================
-- Section 1: Campaign-linked coupon opportunity vs actual redemption
--
-- Task:
-- Compare structural coupon opportunity with actual coupon
-- redemption at household level.
--
-- Note:
-- Households with no redemption are kept in the output to
-- show the gap between coupon exposure and coupon usage.
-- =========================================================
WITH campaign_coupons_combined AS (
    SELECT
        om.household_key,
        om.total_campaigns_assigned,
        om.total_campaign_linked_coupons,
        COALESCE(rm.total_redeemed_coupons, 0) AS total_redeemed_coupons
    FROM vw_07_coupon_opportunity_metrics AS om
    LEFT JOIN vw_07_coupon_redemption_metrics AS rm
        ON om.household_key = rm.household_key
)

SELECT
    COUNT(c.household_key) AS total_households,
    ROUND(AVG(c.total_campaigns_assigned), 2) AS avg_campaigns_assigned,
	ROUND(AVG(c.total_campaign_linked_coupons), 2) AS avg_linked_coupons,
    SUM(c.total_redeemed_coupons) AS total_redeemed_coupons,
    ROUND(AVG(c.total_redeemed_coupons), 2) AS avg_redeemed_coupons,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.total_redeemed_coupons) AS median_redeemed_coupons,
    SUM(CASE WHEN c.total_redeemed_coupons = 0 THEN 1 ELSE 0 END) AS households_with_zero_redemption,
    ROUND(
        SUM(CASE WHEN c.total_redeemed_coupons > 0 THEN 1 ELSE 0 END)::numeric
        / COUNT(c.household_key) * 100,
        2
    ) AS redemption_participation_rate
FROM campaign_coupons_combined AS c;
-- Summary:
-- Coupon opportunity is structurally high, but actual coupon usage is low:
-- most households redeem no coupons at all, and only 27.4% redeem at least one.

-- Analyst explanation:
-- Households are linked to an average of 4.55 campaigns and about 499
-- campaign-linked coupons, but average redemption is only 1.41 coupons
-- per household. The median redeemed coupon count is 0, showing that the
-- typical household does not engage with coupons, while redemption is driven
-- by a smaller subset of households.

-- Business implication:
-- The promotion system appears broad in structure but weak in engagement.
-- This suggests that coupon activity is not translating into widespread
-- customer action, so future strategy should focus on better targeting and
-- identifying which customer groups actually respond to coupons.

-- =========================================================
-- Section 2: Coupon behavior by customer segment
--
-- Task:
-- Compare coupon opportunity and actual coupon redemption
-- across customer segments.
--
-- Note:
-- This section shows whether coupon usage is broadly shared
-- across the customer base or concentrated in specific
-- customer segments.
-- =========================================================
WITH coupon_segment_base AS (
    SELECT
        sc.customer_segment,
        sc.household_key,
        COALESCE(om.total_campaigns_assigned, 0) AS total_campaigns_assigned,
        COALESCE(om.total_campaign_linked_coupons, 0) AS total_campaign_linked_coupons,
        COALESCE(rm.total_redeemed_coupons, 0) AS total_redeemed_coupons
    FROM vw_05_segmented_customers AS sc
    LEFT JOIN vw_07_coupon_opportunity_metrics AS om
        ON sc.household_key = om.household_key
    LEFT JOIN vw_07_coupon_redemption_metrics AS rm
        ON sc.household_key = rm.household_key
)
SELECT
    customer_segment,
    COUNT(household_key) AS households_in_segment,
    ROUND(AVG(total_campaigns_assigned), 2) AS avg_campaigns_assigned,
    ROUND(AVG(total_campaign_linked_coupons), 2) AS avg_linked_coupons,
    ROUND(AVG(total_redeemed_coupons), 2) AS avg_redeemed_coupons,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_redeemed_coupons) AS median_redeemed_coupons,
    SUM(CASE WHEN total_redeemed_coupons > 0 THEN 1 ELSE 0 END) AS households_with_redemption,
    ROUND(
        SUM(CASE WHEN total_redeemed_coupons > 0 THEN 1 ELSE 0 END)::numeric
        / COUNT(household_key) * 100,
        2
    ) AS redemption_participation_rate,
    SUM(total_redeemed_coupons) AS segment_total_redeemed_coupons
FROM coupon_segment_base
GROUP BY customer_segment
ORDER BY segment_total_redeemed_coupons DESC;

-- Summary:
-- Coupon redemption is highly concentrated in high-value, high-frequency customers,
-- who account for the majority of coupon usage, while most other segments show minimal engagement.

-- Analyst explanation:
-- The High Spend / High Frequency segment drives the majority of coupon redemptions
-- (1,981 total) with a participation rate of 35.19%. In contrast, lower-value segments
-- show significantly lower engagement, with participation rates dropping to 17.62%,
-- 8.54%, and 1.33%. Median redemption remains 0 across all segments, indicating that
-- most customers do not redeem coupons at all, even within the most valuable group.

-- Business implication:
-- Coupon usage is concentrated among already valuable customers, raising the question
-- of whether coupons are effectively driving additional behavior or simply rewarding
-- existing purchasing activity. This suggests an opportunity to improve targeting,
-- either by optimizing incentives for high-value customers or by redesigning promotions
-- to better activate lower-engagement segments.