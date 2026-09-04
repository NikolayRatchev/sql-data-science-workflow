-- create CTEs for customer features & target cutomers, join them & select needed columns
-- create the model dataset as a view 
DROP VIEW IF EXISTS public.customer_snapshot_2011_09_01;

CREATE VIEW public.customer_snapshot_2011_09_01 AS

WITH customer_features AS (
    SELECT 
        customer_id, 
        MAX(invoice_date) FILTER (WHERE is_purchase) 
			AS last_purchase_date, 
        DATE '2011-09-01' 
        - (MAX(invoice_date) FILTER (WHERE is_purchase))::date 
        	AS recency_days, 
        COUNT(DISTINCT invoice_no) FILTER (WHERE is_purchase) 
			AS order_count,
        SUM(signed_line_value) FILTER (WHERE is_purchase)
            AS gross_spend,
        SUM(quantity) FILTER (WHERE is_purchase) AS total_items,
        COUNT(DISTINCT stock_code) FILTER (WHERE is_purchase) AS unique_products,
        COUNT(DISTINCT invoice_no)
            FILTER (WHERE is_return_or_cancellation)
            AS return_order_count,

        COALESCE(
            -SUM(signed_line_value)
                FILTER (WHERE is_return_or_cancellation),
            0
        ) AS returned_value,

        SUM(signed_line_value) AS net_spend

    FROM public.online_retail_analytical
    WHERE invoice_date < DATE '2011-09-01' 
    GROUP BY customer_id
    -- Ensure the sample still contains only customers with at least one historical purchase
    HAVING COUNT(*) FILTER (WHERE is_purchase) > 0
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
