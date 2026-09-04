
SELECT *
FROM public.customer_snapshot_2011_09_01
ORDER BY customer_id
LIMIT 10;


SELECT
    COUNT(*) AS total_customers,
    SUM(purchased_next_30_days) AS purchasing_customers,
    ROUND(AVG(purchased_next_30_days::numeric), 3) AS purchase_rate
FROM public.customer_snapshot_2011_09_01;


SELECT
    COUNT(*) AS total_rows,
    COUNT(customer_id) AS non_missing_customer_ids,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(*) - COUNT(customer_id) AS missing_customer_ids,
    COUNT(customer_id) - COUNT(DISTINCT customer_id)
        AS repeated_customer_rows,

    MIN(recency_days) AS min_recency_days,
    MAX(recency_days) AS max_recency_days,
    ROUND(AVG(recency_days), 2) AS average_recency_days,

    MIN(order_count) AS min_order_count,
    MAX(order_count) AS max_order_count,
    ROUND(AVG(order_count), 2) AS average_order_count,

    MIN(total_spend) AS min_total_spend,
    MAX(total_spend) AS max_total_spend,

    SUM(purchased_next_30_days) AS num_positive_targets
FROM public.customer_snapshot_2011_09_01;

-- Expect:
-- total_rows = non_missing_customer_ids = unique_customers = 3317
-- missing_customer_ids = 0
-- repeated_customer_rows = 0
-- num_positive_targets = 967


-- Show the ten customers with the highest total_spend. 
SELECT
    customer_id, 
    total_spend, 
    order_count, 
    total_items, 
    unique_products,
    purchased_next_30_days

FROM public.customer_snapshot_2011_09_01
ORDER BY total_spend DESC 
LIMIT 10;


-- Inspect suspicious customer
SELECT
    invoice_no,
    invoice_date,
    stock_code,
    description,
    quantity,
    unit_price,
    signed_line_value,
    is_purchase,
    is_return_or_cancellation
FROM public.online_retail_analytical
WHERE customer_id = '12346'
ORDER BY invoice_date;


SELECT *
FROM public.customer_snapshot_2011_09_01
WHERE customer_id = '12346';

SELECT
    COUNT(*) AS total_customers,
    SUM(purchased_next_30_days) AS positive_targets
FROM public.customer_snapshot_2011_09_01;