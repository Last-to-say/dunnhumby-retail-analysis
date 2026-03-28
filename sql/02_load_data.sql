-- =========================================================
-- 02_load_data.sql
-- Purpose:
-- Load CSV source files into PostgreSQL tables.
--
-- Logic:
-- 1. Use COPY to import raw data from local CSV files.
-- 2. Keep column order aligned with source headers.
-- 3. Load all tables before starting data audit and join validation.
--
-- Notes:
-- - CSV HEADER tells PostgreSQL to skip the first row of column names.
-- - DELIMITER ',' specifies comma-separated files.
-- =========================================================

COPY campaign_desc(description, campaign, start_day, end_day)
FROM 'D:\Data_Analyst\Portfolio_projects\dunnhumby_analysis\data\campaign_desc.csv'
DELIMITER ','
CSV HEADER;

COPY campaign_table(description, household_key, campaign)
FROM 'D:\Data_Analyst\Portfolio_projects\dunnhumby_analysis\data\campaign_table.csv'
DELIMITER ','
CSV HEADER;

COPY causal_data(product_id, store_id, week_no, display, mailer)
FROM 'D:\Data_Analyst\Portfolio_projects\dunnhumby_analysis\data\causal_data.csv'
DELIMITER ','
CSV HEADER;

COPY coupon(coupon_upc, product_id, campaign)
FROM 'D:\Data_Analyst\Portfolio_projects\dunnhumby_analysis\data\coupon.csv'
DELIMITER ','
CSV HEADER;

COPY coupon_redempt(household_key, day, coupon_upc, campaign)
FROM 'D:\Data_Analyst\Portfolio_projects\dunnhumby_analysis\data\coupon_redempt.csv'
DELIMITER ','
CSV HEADER;

COPY hh_demographic(
	age_desc,
	marital_status_code,
	income_desc,
	homeowner_desc,
	hh_comp_desc,
	household_size_desc,
	kid_category_desc,
	household_key
)
FROM 'D:\Data_Analyst\Portfolio_projects\dunnhumby_analysis\data\hh_demographic.csv'
DELIMITER ','
CSV HEADER;

COPY product(
	product_id,
	manufacturer,
	department,
	brand,
	commodity_desc,
	sub_commodity_desc,
	curr_size_of_product
)
FROM 'D:\Data_Analyst\Portfolio_projects\dunnhumby_analysis\data\product.csv'
DELIMITER ','
CSV HEADER;

COPY transaction_data(
    household_key,
    basket_id,
    day,
    product_id,
    quantity,
    sales_value,
    store_id,
    retail_disc,
    trans_time,
    week_no,
    coupon_disc,
    coupon_match_disc
)
FROM 'D:\Data_Analyst\Portfolio_projects\dunnhumby_analysis\data\transaction_data.csv'
DELIMITER ','
CSV HEADER;