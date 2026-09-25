/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
       - Total orders
       - Total sales
       - Total quantity sold
       - Total customers (unique)
       - Lifespan (in months)
    4. Calculates valuable KPIs:
       - Recency (months since last sale)
       - Average Order Revenue (AOR)
       - Average Monthly Revenue
===============================================================================
*/

WITH base_product_table AS (
    SELECT 
        p.product_key,
        p.product_number,
        f.customer_key,
        f.order_number,
        p.product_name,
        p.category,
        p.subcategory,
        p.product_line,
        p.cost,
        f.sales_amount,
        f.quantity,
        f.order_date
    FROM fact_sales f 
    LEFT JOIN dim_products p
        USING(product_key)
),

product_aggregations AS (
    SELECT 
        product_key,
        product_number,
        product_name,
        category,
        subcategory,
        cost,
        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,
        SUM(sales_amount) AS total_revenue,
        SUM(quantity) AS total_qty,
        MIN(order_date) AS first_purchase_date,
        MAX(order_date) AS latest_purchase_date,
        TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_in_months
    FROM base_product_table
    GROUP BY 
        product_key,
        product_number,
        product_name,
        category,
        subcategory,
        cost
)

SELECT 
    product_key,
    product_number,
    product_name,
    category,
    subcategory,
    cost,
    total_orders,
    total_customers,
    total_revenue,
    total_qty,
    first_purchase_date,
    latest_purchase_date,
    lifespan_in_months,
    
    -- Performance Segmentation
    CASE
        WHEN total_revenue > 190000 THEN 'High'
        WHEN total_revenue BETWEEN 100000 AND 190000 THEN 'Mid'
        ELSE 'Low'
    END AS performance_flag,

    -- Recency
    TIMESTAMPDIFF(MONTH, latest_purchase_date, CURRENT_DATE()) AS recency_in_months,
    
    -- Compute Average Order Revenue
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE total_revenue / total_orders 
    END AS avg_order_revenue,

    -- Compute Average Monthly Revenue
    CASE
        WHEN lifespan_in_months = 0 THEN total_revenue
        ELSE total_revenue / lifespan_in_months
    END AS avg_monthly_revenue,

    -- Compute Average Selling Price
    CASE 
        WHEN total_qty = 0 THEN 0
        ELSE total_revenue / total_qty
    END AS avg_selling_price

FROM product_aggregations;