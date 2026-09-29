-- SQL practice: Build a leakage-safe October snapshot

-- Objective: Create a customer-level dataset suitable for predicting whether a customer will purchase during the next 30 days.

-- Scenario: Your first snapshot used 2011-09-01. Now you need another snapshot dated 2011-10-01, using only information available before that date.

-- Estimated time: 35 minutes

-- Main task — 25 minutes

-- Using online_retail_analytical, write a query that returns one row per eligible customer with:

-- customer_id
-- last_purchase_date
-- recency_days
-- order_count
-- gross_spend
-- return_order_count
-- returned_value
-- purchased_next_30_days

-- Use these rules:

-- Eligible customers: at least one purchase before 2011-10-01.
-- Features: all activity strictly before 2011-10-01.
-- Target window: purchases from 2011-10-01 inclusive to 2011-11-01 exclusive.
-- Preserve customers who do not purchase in the target window.
-- Use three CTEs:
-- eligible_customers
-- customer_features
-- target_customers
-- Use aggregate FILTER clauses for purchase and return features.
-- Avoid hard-coding 2011-10-01 repeatedly by defining a params CTE.

-- Assume the analytical view contains:

-- customer_id
-- invoice_no
-- invoice_date
-- is_purchase
-- is_return_or_cancellation
-- signed_line_value


DROP VIEW IF EXISTS public.customer_snapshot_2011_10_01;

CREATE VIEW public.customer_snapshot_2011_10_01 AS

WITH params AS (
    SELECT
        DATE '2011-10-01' AS snapshot_date,
        DATE '2011-11-01' AS target_end_date
),

eligible_customers AS(
    SELECT DISTINCT ora.customer_id

    FROM public.online_retail_analytical AS ora
    CROSS JOIN params AS p

    WHERE ora.customer_id IS NOT NULL
      AND ora.is_purchase
      AND ora.invoice_date < p.snapshot_date
),

customer_features AS (
    SELECT
        ora.customer_id,
        MAX(ora.invoice_date) FILTER (WHERE ora.is_purchase)
            AS last_purchase_date,
        p.snapshot_date
        - (MAX(ora.invoice_date) FILTER (WHERE ora.is_purchase))::date
            AS recency_days,
        COUNT(DISTINCT ora.invoice_no) FILTER (WHERE ora.is_purchase)
            AS order_count,
        SUM(ora.signed_line_value) FILTER (WHERE ora.is_purchase)
            AS gross_spend,
        SUM(ora.quantity) FILTER (WHERE ora.is_purchase) AS total_items,
        COUNT(DISTINCT ora.stock_code) FILTER (WHERE ora.is_purchase) AS unique_products,
        COUNT(DISTINCT ora.invoice_no)
            FILTER (WHERE ora.is_return_or_cancellation)
            AS return_order_count,

        COALESCE(
            -SUM(ora.signed_line_value)
                FILTER (WHERE ora.is_return_or_cancellation),
            0
        ) AS returned_value,

        SUM(ora.signed_line_value) AS net_spend

    FROM public.online_retail_analytical AS ora

    INNER JOIN eligible_customers AS ec
    ON ora.customer_id = ec.customer_id

    CROSS JOIN params AS p

    WHERE ora.invoice_date < p.snapshot_date

    GROUP BY
        ora.customer_id,
        p.snapshot_date
),
target_customers AS (
    SELECT DISTINCT
        ora.customer_id,
        1 AS purchased_next_30_days

    FROM public.online_retail_analytical AS ora
    CROSS JOIN params AS p
    WHERE ora.is_purchase
        AND ora.invoice_date >= p.snapshot_date
        AND ora.invoice_date < p.target_end_date
)
SELECT
    features.*,
    COALESCE(target.purchased_next_30_days, 0)
    AS purchased_next_30_days

FROM customer_features AS features
LEFT JOIN target_customers AS target
    ON features.customer_id = target.customer_id;


SELECT
    COUNT(*) AS customers,
    COUNT(*) FILTER (
        WHERE purchased_next_30_days = 1
    ) AS positive_customers,
    COUNT(*) FILTER (
        WHERE purchased_next_30_days = 0
    ) AS negative_customers
FROM public.customer_snapshot_2011_10_01;


SELECT
    purchased_next_30_days,
    COUNT(*)
FROM public.customer_snapshot_2011_10_01
GROUP BY purchased_next_30_days
ORDER BY purchased_next_30_days;
