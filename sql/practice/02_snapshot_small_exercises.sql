-- Small exercises

-- Preliminary check: count customers with a purchase before the snapshot
SELECT COUNT(DISTINCT customer_id) AS n_ids
FROM public.online_retail_analytical
WHERE is_purchase
    AND invoice_date < DATE '2011-10-01';


-- Task 1. Build and inspect the October 2011 snapshot step by step

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

-- Direct version: inspect the eligible customer IDs.
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

-- Rebuild the eligible cohort as a named CTE and verify its row count.
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

-- Exercise 4: Calculate customer features from pre-snapshot history
-- For eligible customers, calculate
-- * order_count.
-- * last_purchase_date
-- * gross_spend
-- * return_order_count
-- * returned_value

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

SELECT
    ora.customer_id,

    COUNT(DISTINCT ora.invoice_no)
		FILTER (WHERE ora.is_purchase)
		AS order_count,

	MAX(ora.invoice_date)
		FILTER (WHERE ora.is_purchase)
		AS last_purchase_date,

	SUM(ora.signed_line_value)
		FILTER (WHERE ora.is_purchase)
		AS gross_spend,

	COUNT(DISTINCT ora.invoice_no)
		FILTER (WHERE ora.is_return_or_cancellation)
		AS return_order_count,

	COALESCE(-SUM(ora.signed_line_value)
		FILTER (WHERE ora.is_return_or_cancellation), 0)
		AS returned_value

FROM public.online_retail_analytical AS ora
INNER JOIN eligible_customers AS ec
    ON ora.customer_id = ec.customer_id
CROSS JOIN params AS p
WHERE ora.invoice_date < p.snapshot_date
GROUP BY ora.customer_id
ORDER BY ora.customer_id
LIMIT 10;


-- Exercise 5: Compare invoice categories for one customer
-- Test whether all distinct invoices equal purchase invoices plus
-- return/cancellation invoices.

SELECT
    ora.customer_id,

    COUNT(DISTINCT ora.invoice_no)
        AS all_invoices,

    COUNT(DISTINCT ora.invoice_no)
        FILTER (WHERE ora.is_purchase)
        AS purchase_orders,

    COUNT(DISTINCT ora.invoice_no)
        FILTER (WHERE ora.is_return_or_cancellation)
        AS return_orders

FROM public.online_retail_analytical AS ora
WHERE ora.customer_id = 12346
  AND ora.invoice_date < DATE '2011-10-01'
GROUP BY ora.customer_id;


-- Additional investigation: classify every invoice
-- Determine whether each invoice contains purchase rows, return rows,
-- both types, or neither type.

WITH invoice_classification AS (
    SELECT
        ora.customer_id,
        ora.invoice_no,

        BOOL_OR(ora.is_purchase)
            AS contains_purchase,

        BOOL_OR(ora.is_return_or_cancellation)
            AS contains_return

    FROM public.online_retail_analytical AS ora
    GROUP BY
        ora.customer_id,
        ora.invoice_no
)

SELECT
    contains_purchase,
    contains_return,
    COUNT(*) AS invoice_count
FROM invoice_classification
GROUP BY
    contains_purchase,
    contains_return
ORDER BY
    contains_purchase,
    contains_return;

-- Identify invoices containing neither purchase nor return rows.

WITH invoice_classification AS (
    SELECT
        ora.customer_id,
        ora.invoice_no,

        BOOL_OR(ora.is_purchase)
            AS contains_purchase,

        BOOL_OR(ora.is_return_or_cancellation)
            AS contains_return

    FROM public.online_retail_analytical AS ora
    GROUP BY
        ora.customer_id,
        ora.invoice_no
)

SELECT
    customer_id,
    invoice_no
FROM invoice_classification
WHERE NOT contains_purchase
  AND NOT contains_return
ORDER BY invoice_no;

-- Inspect the rows belonging to invoices in neither category.

WITH invoice_classification AS (
    SELECT
        ora.customer_id,
        ora.invoice_no,

        BOOL_OR(ora.is_purchase)
            AS contains_purchase,

        BOOL_OR(ora.is_return_or_cancellation)
            AS contains_return

    FROM public.online_retail_analytical AS ora
    GROUP BY
        ora.customer_id,
        ora.invoice_no
),

other_invoices AS (
    SELECT
        customer_id,
        invoice_no
    FROM invoice_classification
    WHERE NOT contains_purchase
      AND NOT contains_return
)

SELECT
    ora.*
FROM public.online_retail_analytical AS ora
INNER JOIN other_invoices AS oi
    ON ora.customer_id = oi.customer_id
   AND ora.invoice_no = oi.invoice_no
ORDER BY
    ora.invoice_no,
    ora.row_id;

-- Finding: four invoices contain positive-quantity, zero-price rows.
-- Treat them as "other": retain them in the analytical view, but exclude
-- them from purchase and return features because their business meaning
-- cannot be determined from the available data.

-- Exercise 6: Build the target independently
-- Count eligible pre-snapshot customers who purchased during October.

WITH params AS (
    SELECT
        DATE '2011-10-01' AS snapshot_date,
        DATE '2011-11-01' AS target_end_date
),

eligible_customers AS (
    SELECT DISTINCT
        ora.customer_id
    FROM public.online_retail_analytical AS ora
    CROSS JOIN params AS p
    WHERE ora.customer_id IS NOT NULL
      AND ora.is_purchase
      AND ora.invoice_date < p.snapshot_date
),

target_customers AS (
    SELECT DISTINCT
        ora.customer_id,
        1 AS purchased_next_30_days
    FROM public.online_retail_analytical AS ora
    CROSS JOIN params AS p
    WHERE ora.customer_id IS NOT NULL
      AND ora.is_purchase
      AND ora.invoice_date >= p.snapshot_date
      AND ora.invoice_date < p.target_end_date
)

SELECT
    COUNT(*) AS eligible_positive_customers
FROM eligible_customers AS ec
INNER JOIN target_customers AS tc
    ON ec.customer_id = tc.customer_id;

-- Note: [2011-10-01, 2011-11-01) represents the next calendar month
-- (31 days), although the existing project target is named purchased_next_30_days.


-- Exercise 7: Preserve the snapshot cohort with a LEFT JOIN
-- Count positive and negative target cases among all eligible customers.

WITH params AS (
    SELECT
        DATE '2011-10-01' AS snapshot_date,
        DATE '2011-11-01' AS target_end_date
),

eligible_customers AS (
    SELECT DISTINCT
        ora.customer_id
    FROM public.online_retail_analytical AS ora
    CROSS JOIN params AS p
    WHERE ora.customer_id IS NOT NULL
      AND ora.is_purchase
      AND ora.invoice_date < p.snapshot_date
),

target_customers AS (
    SELECT DISTINCT
        ora.customer_id,
        1 AS purchased_next_30_days
    FROM public.online_retail_analytical AS ora
    CROSS JOIN params AS p
    WHERE ora.customer_id IS NOT NULL
      AND ora.is_purchase
      AND ora.invoice_date >= p.snapshot_date
      AND ora.invoice_date < p.target_end_date
)

SELECT COUNT(*)
    AS snapshot_customers,
	COUNT(*) FILTER (
		WHERE tc.customer_id IS NOT NULL
	) AS positive_customers,
	COUNT(*) FILTER (
		WHERE tc.customer_id IS NULL
	) AS negative_customers

FROM eligible_customers AS ec
LEFT JOIN target_customers AS tc
    ON ec.customer_id = tc.customer_id;
