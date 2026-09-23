-- ==============================================================================
-- PROJECT: E-Commerce Exploratory Data Analysis (EDA)
-- FILE: ecommerce project EDA.sql
-- DESCRIPTION: End-to-end data exploration, cleaning, and advanced business 
--              performance analysis using sales and dimensional data.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. SCHEMA VERIFICATION & DATA CLEANING
-- ------------------------------------------------------------------------------

-- Verify available tables in the data warehouse
SELECT * 
FROM information_schema.tables 
WHERE TABLE_SCHEMA = 'salesdw';

-- Fill missing categorical values with defaults
UPDATE dim_products 
SET category = 'Accessories', 
    subcategory = 'Pedal' 
WHERE category = '' AND subcategory = '';

UPDATE dim_products 
SET maintenance = 'No' 
WHERE maintenance = '';

-- Impute missing/zero costs for 'Road Frames' using the category average
UPDATE dim_products 
SET cost = (
    SELECT avg_cost 
    FROM (
        SELECT ROUND(AVG(cost), 2) AS avg_cost 
        FROM dim_products 
        WHERE category = 'components' 
          AND subcategory = 'road frames' 
          AND cost > 0
    ) temp
)
WHERE category = 'components' 
  AND subcategory = 'road frames' 
  AND cost = 0;

-- ------------------------------------------------------------------------------
-- 2. CUSTOMER DEMOGRAPHICS & DIMENSION ANALYSIS
-- ------------------------------------------------------------------------------

-- Customer Base Overview
SELECT 
    COUNT(*) AS total_records,
    COUNT(DISTINCT customer_id) AS unique_customers,
    MAX(birthdate) AS youngest_birthdate,
    MIN(birthdate) AS oldest_birthdate
FROM dim_customers;

-- Age Distribution: Youngest and Oldest Customers
SELECT 
    CONCAT(TIMESTAMPDIFF(YEAR, MAX(birthdate), CURRENT_DATE()), ' Yrs') AS youngest_customer, 
    CONCAT(TIMESTAMPDIFF(YEAR, MIN(birthdate), CURRENT_DATE()), ' Yrs') AS oldest_customer 
FROM dim_customers;

-- Customer Segmentation by Geography, Gender, and Marital Status
SELECT 
    country, 
    gender, 
    marital_status, 
    COUNT(*) AS total_customers
FROM dim_customers
GROUP BY 
    country, 
    gender, 
    marital_status
ORDER BY total_customers DESC;

-- ------------------------------------------------------------------------------
-- 3. PRODUCT CATALOG ANALYSIS
-- ------------------------------------------------------------------------------

-- Product Catalog Breadth
SELECT 
    COUNT(product_name) AS total_products, 
    COUNT(DISTINCT product_name) AS unique_products 
FROM dim_products;

-- Average Cost by Product Category
SELECT 
    category, 
    ROUND(AVG(cost), 2) AS average_cost
FROM dim_products
GROUP BY category
ORDER BY average_cost DESC;

-- ------------------------------------------------------------------------------
-- 4. KEY PERFORMANCE INDICATORS (KPIs) & EXECUTIVE SUMMARY
-- ------------------------------------------------------------------------------

-- Unified Business Metrics Report
SELECT 'Total Sales' AS measure_name, SUM(sales_amount) AS measure_value FROM fact_sales
UNION ALL
SELECT 'Total Quantity', SUM(quantity) FROM fact_sales
UNION ALL
SELECT 'Average Selling Price', ROUND(AVG(price), 2) FROM fact_sales
UNION ALL
SELECT 'Total Orders', COUNT(DISTINCT order_number) FROM fact_sales
UNION ALL
SELECT 'Total Products Catalogued', COUNT(product_id) FROM dim_products
UNION ALL
SELECT 'Total Active Customers', COUNT(DISTINCT customer_key) FROM fact_sales;

-- ------------------------------------------------------------------------------
-- 5. MAGNITUDE & PROPORTIONAL ANALYSIS
-- ------------------------------------------------------------------------------

-- Regional Revenue Distribution
SELECT 
    c.country,
    SUM(f.sales_amount) AS total_sales
FROM fact_sales f 
LEFT JOIN dim_customers c USING(customer_key)
GROUP BY c.country
ORDER BY total_sales DESC;

-- Category Contribution to Total Revenue (Percentage of Total)
WITH category_sales AS (
    SELECT 
        p.category, 
        SUM(f.sales_amount) AS total_sale
    FROM fact_sales f 
    LEFT JOIN dim_products p USING(product_key)
    GROUP BY p.category
)
SELECT 
    category, 
    total_sale, 
    SUM(total_sale) OVER() AS overall_sales,
    CONCAT(ROUND((total_sale / SUM(total_sale) OVER()), 2) * 100, ' %') AS percentage_contribution
FROM category_sales
ORDER BY total_sale DESC;

-- ------------------------------------------------------------------------------
-- 6. RANKING ANALYSIS
-- ------------------------------------------------------------------------------

-- Top 3 Revenue-Generating Countries
SELECT * FROM (
    SELECT 
        c.country, 
        SUM(f.sales_amount) AS total_sales,
        RANK() OVER (ORDER BY SUM(f.sales_amount) DESC) AS sales_rank
    FROM fact_sales f 
    LEFT JOIN dim_customers c USING(customer_key)
    GROUP BY c.country
) temp
WHERE sales_rank <= 3;

-- Top 5 Most Popular Products per Country by Volume
SELECT * FROM (
    SELECT 
        c.country, 
        p.product_name, 
        SUM(f.quantity) AS sold_qty,
        DENSE_RANK() OVER (PARTITION BY c.country ORDER BY SUM(f.quantity) DESC) AS product_rank
    FROM fact_sales f 
    LEFT JOIN dim_products p USING(product_key)
    LEFT JOIN dim_customers c USING(customer_key)
    GROUP BY c.country, p.product_name
) temp
WHERE product_rank <= 5;

-- ------------------------------------------------------------------------------
-- 7. ADVANCED ANALYSIS: TIME SERIES & MOVING AVERAGES
-- ------------------------------------------------------------------------------

-- Year-over-Year (YoY) Sales and Volume Trends
SELECT 
    YEAR(order_date) AS order_year, 
    SUM(sales_amount) AS total_sales, 
    COUNT(DISTINCT customer_key) AS active_customers, 
    SUM(quantity) AS total_qty
FROM fact_sales
GROUP BY YEAR(order_date)
HAVING order_year IS NOT NULL
ORDER BY order_year;

-- Cumulative Sales and Moving Averages
WITH monthly_metrics AS (
    SELECT 
        DATE_FORMAT(order_date, '%Y-%m') AS order_month, 
        SUM(sales_amount) AS monthly_sales,
        AVG(price) AS average_price
    FROM fact_sales
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
    HAVING order_month IS NOT NULL
)
SELECT 
    order_month, 
    monthly_sales,
    SUM(monthly_sales) OVER (ORDER BY order_month) AS running_total_sales,
    ROUND(AVG(average_price) OVER (ORDER BY order_month ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING), 2) AS centered_moving_avg_price
FROM monthly_metrics;

-- ------------------------------------------------------------------------------
-- 8. BEHAVIORAL SEGMENTATION
-- ------------------------------------------------------------------------------

-- Product Portfolio Segmentation by Price Tier
WITH product_tiers AS (
    SELECT 
        product_key,
        product_name,
        cost,
        CASE
            WHEN cost < 249 THEN 'Entry (Below 249)'
            WHEN cost BETWEEN 250 AND 500 THEN 'Mid-Tier (250 - 500)'
            WHEN cost BETWEEN 501 AND 799 THEN 'Upper Mid (501 - 799)'
            WHEN cost BETWEEN 800 AND 2000 THEN 'Premium (800 - 2000)'
            ELSE 'Luxury (Above 2000)'
        END AS cost_tier
    FROM dim_products
)
SELECT 
    cost_tier,
    COUNT(*) AS product_count
FROM product_tiers
GROUP BY cost_tier
ORDER BY product_count DESC;

-- Customer Lifetime Value (CLV) Segmentation
WITH customer_spending AS (
    SELECT 
        c.customer_key, 
        TIMESTAMPDIFF(MONTH, MIN(f.order_date), MAX(f.order_date)) AS lifespan_months,
        SUM(f.sales_amount) AS total_spending
    FROM fact_sales f 
    LEFT JOIN dim_customers c USING(customer_key)
    GROUP BY c.customer_key
),
customer_segments AS (
    SELECT 
        customer_key,
        CASE 
            WHEN total_spending > 5000 AND lifespan_months >= 12 THEN 'VIP'
            WHEN total_spending <= 5000 AND lifespan_months >= 12 THEN 'Regular'
            ELSE 'New'
        END AS segment_group
    FROM customer_spending
)
SELECT 
    segment_group, 
    COUNT(customer_key) AS customer_count
FROM customer_segments
GROUP BY segment_group
ORDER BY customer_count DESC;