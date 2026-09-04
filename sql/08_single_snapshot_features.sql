-- create the model dataset as a view 
CREATE OR REPLACE VIEW public.customer_snapshot_2011_09_01 AS

-- create CTEs for customer features & target cutomers, join them & select needed columns
WITH customer_features AS (
    SELECT 
        customer_id, 
        MAX(invoice_date) AS last_purchase_date, 
        DATE '2011-09-01' - MAX(invoice_date)::date AS recency_days, 
        COUNT(DISTINCT invoice_no) AS order_count,
        SUM(quantity * unit_price) AS total_spend,
        SUM(quantity) AS total_items,
        COUNT(DISTINCT stock_code) AS unique_products
    FROM public.online_retail_analytical
    WHERE invoice_date < DATE '2011-09-01' AND is_purchase
    GROUP BY customer_id
), 
target_customers AS (
    -- Target customers 
    SELECT DISTINCT 
        customer_id, 
        1 AS purchased_next_30_days
    FROM public.online_retail_analytical
    WHERE invoice_date >= DATE '2011-09-01' 
        AND invoice_date < DATE '2011-10-01'
        AND is_purchase 
)
SELECT 
    features.*, 
    COALESCE(target.purchased_next_30_days, 0)
    AS purchased_next_30_days

FROM customer_features AS features
LEFT JOIN target_customers AS target 
    ON features.customer_id = target.customer_id;


-- Validations
SELECT *
FROM public.customer_snapshot_2011_09_01
ORDER BY customer_id
LIMIT 10;


SELECT
    COUNT(*) AS total_customers,
    SUM(purchased_next_30_days) AS purchasing_customers,
    ROUND(AVG(purchased_next_30_days::numeric), 3) AS purchase_rate
FROM public.customer_snapshot_2011_09_01;


