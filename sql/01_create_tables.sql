-- =========================================================
-- 01_create_tables.sql
-- Purpose:
-- Create the core tables for the Dunnhumby retail analysis project.
--
-- Logic:
-- 1. Drop existing tables to allow clean re-runs during setup.
-- 2. Recreate tables with explicit column definitions.
-- 3. Use safe data types for initial loading and later validation.
--
-- Notes:
-- - INTEGER/BIGINT are used for IDs and whole-number fields.
-- - NUMERIC is used for sales and discount values.
-- - TEXT is used for descriptive/category fields.
-- =========================================================

DROP TABLE IF EXISTS campaign_desc;
DROP TABLE IF EXISTS campaign_table;
DROP TABLE IF EXISTS causal_data;
DROP TABLE IF EXISTS coupon;
DROP TABLE IF EXISTS coupon_redempt;
DROP TABLE IF EXISTS hh_demographic;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS transaction_data;

CREATE TABLE campaign_desc (
    description TEXT,
    campaign INTEGER,
    start_day INTEGER,
    end_day INTEGER
);

CREATE TABLE campaign_table (
    description TEXT,
    household_key INTEGER,
    campaign INTEGER
);

CREATE TABLE causal_data (
    product_id INTEGER,
    store_id INTEGER,
    week_no INTEGER,
    display TEXT,
    mailer TEXT
);

CREATE TABLE coupon (
    coupon_upc BIGINT,
    product_id INTEGER,
    campaign INTEGER
);

CREATE TABLE coupon_redempt (
    household_key INTEGER,
    day INTEGER,
    coupon_upc BIGINT,
    campaign INTEGER
);

CREATE TABLE hh_demographic (
    age_desc TEXT,
    marital_status_code TEXT,
    income_desc TEXT,
    homeowner_desc TEXT,
    hh_comp_desc TEXT,
    household_size_desc TEXT,
    kid_category_desc TEXT,
    household_key INTEGER
);

CREATE TABLE product (
    product_id INTEGER,
    manufacturer INTEGER,
    department TEXT,
    brand TEXT,
    commodity_desc TEXT,
    sub_commodity_desc TEXT,
    curr_size_of_product TEXT
);

CREATE TABLE transaction_data (
    household_key INTEGER,
    basket_id BIGINT,
    day INTEGER,
    product_id INTEGER,
    quantity NUMERIC(12,2),
    sales_value NUMERIC(12,2),
    store_id INTEGER,
    retail_disc NUMERIC(12,2),
    trans_time INTEGER,
    week_no INTEGER,
    coupon_disc NUMERIC(12,2),
    coupon_match_disc NUMERIC(12,2)
);