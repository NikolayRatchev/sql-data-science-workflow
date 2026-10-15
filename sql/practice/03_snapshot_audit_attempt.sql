-- Audit the snapshot grain


-- Exercise 1.

-- Using only `public.customer_snapshot_2011_10_01`
-- write one query returning:
-- - total number of rows;
-- - number of distinct customer_id values;
-- - number of rows with a null customer_id.

SELECT
	COUNT(*) AS total_rows,
	COUNT(DISTINCT customer_id) AS num_distinct_ids,
	COUNT(*) FILTER (
		WHERE customer_id IS NULL
	) AS null_customer_ids
FROM public.customer_snapshot_2011_10_01;

SELECT *
FROM public.customer_snapshot_2011_10_01
LIMIT 10;


-- Exercise 2.

-- Write a query using `public.customer_snapshot_2011_10_01`
-- that returns one row for each distinct value of `purchased_next_30_days`,
-- together with the number of customers having that value.

-- Predictions
-- values are 0 and 1
-- 1 = 1006 customers; 0 = 2610 customers,
-- summing up to 3616

SELECT
	purchased_next_30_days AS purchase_value,
	COUNT(*) AS total_count
FROM public.customer_snapshot_2011_10_01
GROUP BY purchased_next_30_days
ORDER BY purchased_next_30_days;


-- Exercise 3.

-- Calculate total customers, positive customers, and the target rate.
-- Prediction: Rate is slightly below 0.30

SELECT
	COUNT(*) AS total_customers,
	COUNT(*) FILTER (WHERE purchased_next_30_days = 1) AS positive_customers,
	ROUND(COUNT(*) FILTER (WHERE purchased_next_30_days = 1) * 1.0 / COUNT(*), 3) AS target_rate
FROM public.customer_snapshot_2011_10_01;


-- Exercise 4.

-- Write one query returning:
-- - minimum recency_days;
-- - maximum recency_days;
-- - number of null values;
-- - number of negative values.

-- Predictions
-- 1. Should any value be negative?
-- NO.
-- 2. Should any value be null, given how the eligible cohort was defined?
-- Initial prediction: YES, null values could exist.
-- Correction: eligibility guarantees at least one historical purchase,
-- so last_purchase_date and recency_days cannot be null.
-- 3. Is a minimum of 0 possible when feature rows must occur strictly before 2011-10-01?
-- NO, the minimal value should be 1.

SELECT
	MIN(recency_days) AS minimum_recency_days,
	MAX(recency_days) AS maximum_recency_days,
	COUNT(*) FILTER (WHERE recency_days IS NULL) AS null_recency_days,
	COUNT(*) FILTER (WHERE recency_days < 0) AS negative_recency_days
FROM public.customer_snapshot_2011_10_01;


-- Exercise 5. Audit order_count

-- Write one query returning:
-- - minimum order_count;
-- - maximum order_count;
-- - number of null values;
-- - number of customers with order_count = 0.

-- Prediction
-- Do any null or zero values should exist?
-- NO, because eligible_customers have been defined to have at least one purchase before snapshot date.

SELECT
	MIN(order_count) AS minimum_order_count,
	MAX(order_count) AS maximum_order_count,
	COUNT(*) FILTER (WHERE order_count IS NULL) AS null_order_count,
	COUNT(*) FILTER (WHERE order_count = 0) AS zero_order_count
FROM public.customer_snapshot_2011_10_01;


-- Exercise 6. Final financial-feature sanity check

-- Using customer_snapshot_2011_10_01, write one query returning:
-- - minimum gross_spend;
-- - minimum returned_value;
-- - minimum net_spend;
-- - count of negative gross_spend values;
-- - count of negative returned_value values;
-- - count of negative net_spend values.

-- Prediction
-- Can each of the three features can be negative?
-- Only net_spend can be negative. Gross_spend should be positive,
-- while returned_value is non-negative by construction.

SELECT
	MIN(gross_spend) AS minimum_gross_spend,
	MIN(returned_value) AS minimum_returned_value,
	MIN(net_spend) AS minimum_net_spend,
	COUNT(*) FILTER (WHERE gross_spend < 0) AS negative_gross_spend,
	COUNT(*) FILTER (WHERE returned_value < 0) AS negative_returned_value,
	COUNT(*) FILTER (WHERE net_spend < 0) AS negative_net_spend
FROM public.customer_snapshot_2011_10_01;
