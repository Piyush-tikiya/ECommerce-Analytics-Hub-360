/*
===============================================================================
Customer Report
===============================================================================
Purpose:
    - This report consolidates key customer metrics and behaviors.

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
    2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
       - Total orders
       - Total sales
       - Total quantity purchased
       - Total products
       - Lifespan (in months)
    4. Calculates valuable KPIs:
       - Recency (months since last order)
       - Average Order Value (AOV)
       - Average Monthly Spend
===============================================================================
*/

WITH base_table AS (
    SELECT 
        f.customer_key, 
        f.product_key,
        c.customer_number,
        f.order_number,
        f.order_date,
        CONCAT(c.first_name, ' ', c.last_name) AS full_name,
        f.sales_amount,
        f.quantity,
        c.country,
        c.gender,
        c.marital_status,
        TIMESTAMPDIFF(YEAR, c.birthdate, CURRENT_DATE()) AS age
    FROM fact_sales f 
    LEFT JOIN dim_customers c
        USING(customer_key)
),

customer_aggregations AS (
    SELECT 
        customer_key,
        customer_number,
        full_name,
        age,
        SUM(sales_amount) AS total_order_amount,
        SUM(quantity) AS total_qty,
        COUNT(DISTINCT order_number) AS total_orders,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,
        TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_in_months,
        TIMESTAMPDIFF(MONTH, MAX(order_date), CURRENT_DATE()) AS recency_in_months
    FROM base_table
    GROUP BY    
        customer_key,
        customer_number,
        full_name,
        age
)

SELECT 
    customer_key,
    customer_number,
    full_name, 
    age,
    
    -- Age Group Segmentation
    CASE 
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 30 THEN '20 - 30'
        WHEN age BETWEEN 31 AND 40 THEN '31 - 40'
        WHEN age BETWEEN 41 AND 50 THEN '41 - 50'
        ELSE '> 50'
    END AS age_group,
    
    lifespan_in_months,
    total_order_amount,
    
    -- Customer Segmentation
    CASE 
        WHEN total_order_amount > 5000 AND lifespan_in_months >= 12 THEN 'VIP'
        WHEN total_order_amount <= 5000 AND lifespan_in_months >= 12 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    
    total_qty,
    total_orders,
    first_order_date,
    last_order_date,
    recency_in_months,
    
    -- Compute Average Order Value (AOV)
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_order_amount / total_orders
    END AS average_order_value,
    
    -- Compute Average Selling 
    CASE
        WHEN total_qty = 0 THEN 0
        ELSE total_order_amount / total_qty
    END AS average_selling_price,
    
    -- Compute Average Monthly Spend
    CASE
        WHEN lifespan_in_months = 0 THEN total_order_amount
        ELSE total_order_amount / lifespan_in_months
    END AS average_monthly_spend
    
FROM customer_aggregations;