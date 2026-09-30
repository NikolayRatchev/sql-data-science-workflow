
SELECT COUNT(DISTINCT customer_id) AS n_ids
FROM public.online_retail_analytical
WHERE is_purchase
    AND invoice_date < DATE '2011-10-01';


-- Task 1

-- Exercise 1: Create and inspect parameters
-- Write a query containing only the params CTE, then display its contents

WITH params AS (
    SELECT
        DATE '2011-10-01' AS snapshot_date,
        DATE '2011-11-01' AS target_end_date
)
SELECT *
FROM params;


-- Exercise 2: Use a parameter in a simple filter
-- Count all rows occurring before the snapshot date.

-- Solution 1
WITH params AS (
    SELECT
        DATE '2011-10-01' AS snapshot_date
)
SELECT
    COUNT(*) AS pre_snapshot_rows
FROM public.online_retail_analytical AS ora
CROSS JOIN params AS p
WHERE ora.invoice_date < p.snapshot_date;

-- Solution 2
SELECT COUNT(*)
FROM public.online_retail_analytical
WHERE invoice_date < DATE '2011-10-01';


-- Exercise 3: Identify eligible customers
-- Return one row per customer who made at least one purchase before the snapshot

WITH params AS (
    SELECT
        DATE '2011-10-01' AS snapshot_date
)
SELECT DISTINCT
    ora.customer_id
FROM public.online_retail_analytical AS ora
CROSS JOIN params AS p
WHERE
    ora.customer_id IS NOT NULL AND
    ora.is_purchase AND
    ora.invoice_date < p.snapshot_date
ORDER BY ora.customer_id;

-- place that query inside a second CTE.
WITH params AS (
    SELECT
        DATE '2011-10-01' AS snapshot_date
),

eligible_customers AS (
    SELECT DISTINCT
        ora.customer_id
    FROM public.online_retail_analytical AS ora
    CROSS JOIN params AS p
    WHERE ora.customer_id IS NOT NULL
      AND ora.is_purchase
      AND ora.invoice_date < p.snapshot_date
)

SELECT COUNT(*) AS eligible_customer_count
FROM eligible_customers;

-- Exercise 4: Calculate one feature only
-- For eligible customers, calculate only order_count. Do not add the other features yet.

-- WORK IN PROGRESS:
-- This is my initial attempt. Some aggregate expressions require revision.
-- Preserve it temporarily for later review and correction.

WITH params AS (
    SELECT
        DATE '2011-10-01' AS snapshot_date
),

eligible_customers AS (
    SELECT DISTINCT
        ora.customer_id,
		p.snapshot_date
    FROM public.online_retail_analytical AS ora
    CROSS JOIN params AS p
    WHERE ora.customer_id IS NOT NULL
      AND ora.is_purchase
      AND ora.invoice_date < p.snapshot_date
)

SELECT
    ora.customer_id,
    COUNT (DISTINCT ora.invoice_no) AS distinct_purchases,
	MAX(invoice_date) AS last_purchase_date,
	SUM(signed_line_value) FILTER (WHERE is_purchase) AS gross_spend,
	COUNT(is_return_or_cancellation) AS return_order_count,
	COALESCE(-SUM(signed_line_value) FILTER (WHERE is_return_or_cancellation), 0) AS returned_value
FROM public.online_retail_analytical AS ora
INNER JOIN eligible_customers AS ec
    ON ora.customer_id = ec.customer_id
CROSS JOIN params AS p
WHERE ora.invoice_date < p.snapshot_date
GROUP BY ora.customer_id
ORDER BY ora.customer_id
LIMIT 10;
