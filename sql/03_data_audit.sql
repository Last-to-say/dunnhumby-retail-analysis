-- =========================================================
-- 03_data_audit.sql
-- Purpose:
-- Perform initial audit checks after data loading.
--
-- Logic:
-- 1. Confirm row counts across all tables.
-- 2. Test whether likely key columns are unique.
-- 3. Measure distinct values in important business fields.
-- 4. Check for nulls in critical columns.
-- 5. Validate grain assumptions in transaction data.
-- 6. Inspect quantity behavior and financial ranges.
--
-- Goal:
-- Understand the structure, reliability, and modeling risks
-- before starting joins and business analysis.
-- =========================================================


-- ---------------------------------------------------------
-- Section 1: Row count checks
-- Confirms that all tables were loaded successfully and
-- shows the scale of each dataset.
-- ---------------------------------------------------------

SELECT 'campaign_desc' AS table_name, COUNT(*) AS row_count
FROM campaign_desc

UNION ALL

SELECT 'campaign_table', COUNT(*)
FROM campaign_table

UNION ALL

SELECT 'causal_data', COUNT(*)
FROM causal_data

UNION ALL

SELECT 'coupon', COUNT(*)
FROM coupon

UNION ALL

SELECT 'coupon_redempt', COUNT(*)
FROM coupon_redempt

UNION ALL

SELECT 'hh_demographic', COUNT(*)
FROM hh_demographic

UNION ALL

SELECT 'product', COUNT(*)
FROM product

UNION ALL

SELECT 'transaction_data', COUNT(*)
FROM transaction_data;


-- ---------------------------------------------------------
-- Section 2: Candidate key checks
-- Tests whether likely primary key columns are unique.
-- If duplicates exist, joins may multiply rows incorrectly.
-- ---------------------------------------------------------

-- Check whether campaign is unique in campaign_desc
SELECT
    campaign,
    COUNT(*) AS row_count
FROM campaign_desc
GROUP BY campaign
HAVING COUNT(*) > 1;

-- Check whether household_key is unique in hh_demographic
SELECT
    household_key,
    COUNT(*) AS row_count
FROM hh_demographic
GROUP BY household_key
HAVING COUNT(*) > 1;

-- Check whether product_id is unique in product
SELECT
    product_id,
    COUNT(*) AS row_count
FROM product
GROUP BY product_id
HAVING COUNT(*) > 1;


-- ---------------------------------------------------------
-- Section 3: Distinct value checks
-- Measures dataset coverage and helps us understand scale,
-- granularity, and business variety.
-- ---------------------------------------------------------

-- Distinct coverage of key business entities in transaction_data
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT household_key) AS distinct_households,
    COUNT(DISTINCT basket_id) AS distinct_baskets,
    COUNT(DISTINCT product_id) AS distinct_products,
    COUNT(DISTINCT store_id) AS distinct_stores,
    COUNT(DISTINCT week_no) AS distinct_weeks
FROM transaction_data;

-- Distinct coverage in campaign_table
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT household_key) AS distinct_households,
    COUNT(DISTINCT campaign) AS distinct_campaigns,
    COUNT(DISTINCT description) AS distinct_descriptions
FROM campaign_table;

-- Distinct coverage in coupon_redempt
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT household_key) AS distinct_households,
    COUNT(DISTINCT coupon_upc) AS distinct_coupons,
    COUNT(DISTINCT campaign) AS distinct_campaigns
FROM coupon_redempt;


-- ---------------------------------------------------------
-- Section 4: Null checks
-- Checks whether critical columns are missing values.
-- Nulls in key or business-critical columns may break joins
-- or distort analysis.
-- ---------------------------------------------------------

-- Null check for critical transaction_data columns
SELECT
    SUM(CASE WHEN household_key IS NULL THEN 1 ELSE 0 END) AS null_household_key,
    SUM(CASE WHEN basket_id IS NULL THEN 1 ELSE 0 END) AS null_basket_id,
    SUM(CASE WHEN day IS NULL THEN 1 ELSE 0 END) AS null_day,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) AS null_quantity,
    SUM(CASE WHEN sales_value IS NULL THEN 1 ELSE 0 END) AS null_sales_value
FROM transaction_data;

-- Null check for critical product columns
SELECT
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN department IS NULL THEN 1 ELSE 0 END) AS null_department,
    SUM(CASE WHEN brand IS NULL THEN 1 ELSE 0 END) AS null_brand,
    SUM(CASE WHEN commodity_desc IS NULL THEN 1 ELSE 0 END) AS null_commodity_desc
FROM product;

-- Null check for critical household demographic columns
SELECT
    SUM(CASE WHEN household_key IS NULL THEN 1 ELSE 0 END) AS null_household_key,
    SUM(CASE WHEN age_desc IS NULL THEN 1 ELSE 0 END) AS null_age_desc,
    SUM(CASE WHEN income_desc IS NULL THEN 1 ELSE 0 END) AS null_income_desc
FROM hh_demographic;


-- ---------------------------------------------------------
-- Section 5: Grain validation
-- Validates the working grain assumption for transaction_data.
-- We expect one row to represent one product line within a basket.
-- ---------------------------------------------------------

-- Identify baskets with the highest number of line items
SELECT
    basket_id,
    COUNT(*) AS line_count
FROM transaction_data
GROUP BY basket_id
ORDER BY line_count DESC
LIMIT 20;

-- Identify household-basket combinations with many distinct products
SELECT
    household_key,
    basket_id,
    COUNT(DISTINCT product_id) AS distinct_products
FROM transaction_data
GROUP BY household_key, basket_id
ORDER BY distinct_products DESC
LIMIT 20;


-- ---------------------------------------------------------
-- Section 6: Quantity audit
-- Checks whether quantity behaves like a whole-number field
-- or contains fractional values.
-- ---------------------------------------------------------

-- Distribution of quantity values
SELECT
    quantity,
    COUNT(*) AS row_count
FROM transaction_data
GROUP BY quantity
ORDER BY quantity
LIMIT 50;

-- Count rows where quantity is not an integer value
SELECT
    COUNT(*) AS non_integer_quantity_rows
FROM transaction_data
WHERE quantity <> FLOOR(quantity);


-- ---------------------------------------------------------
-- Section 7: Financial sanity checks
-- Reviews min/max ranges for sales and discount fields to
-- detect unusual or potentially invalid values.
-- ---------------------------------------------------------

SELECT
    MIN(sales_value) AS min_sales_value,
    MAX(sales_value) AS max_sales_value,
    MIN(retail_disc) AS min_retail_disc,
    MAX(retail_disc) AS max_retail_disc,
    MIN(coupon_disc) AS min_coupon_disc,
    MAX(coupon_disc) AS max_coupon_disc,
    MIN(coupon_match_disc) AS min_coupon_match_disc,
    MAX(coupon_match_disc) AS max_coupon_match_disc
FROM transaction_data;