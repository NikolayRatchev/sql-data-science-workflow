-- ============================================================
-- 1. Basic dataset dimensions and date coverage
-- ============================================================

SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT invoice_no) AS invoice_count,
    COUNT(DISTINCT stock_code) AS product_count,
    COUNT(DISTINCT customer_id) AS identified_customer_count,
    MIN(invoice_date) AS first_transaction,
    MAX(invoice_date) AS last_transaction
FROM online_retail;


-- ============================================================
-- 2. Missing values
-- ============================================================

-- SELECT
--     COUNT(*) FILTER (
--         WHERE invoice_no IS NULL
--     ) AS missing_invoice_no,

--     COUNT(*) FILTER (
--         WHERE stock_code IS NULL
--     ) AS missing_stock_code,

--     COUNT(*) FILTER (
--         WHERE description IS NULL
--            OR TRIM(description) = ''
--     ) AS missing_description,

--     COUNT(*) FILTER (
--         WHERE customer_id IS NULL
--            OR TRIM(customer_id) = ''
--     ) AS missing_customer_id,

--     COUNT(*) FILTER (
--         WHERE country IS NULL
--            OR TRIM(country) = ''
--     ) AS missing_country
-- FROM online_retail;

SELECT
    SUM(CASE WHEN invoice_no IS NULL THEN 1 ELSE 0 END) AS missing_invoice_no,
    SUM(CASE WHEN stock_code IS NULL THEN 1 ELSE 0 END) AS missing_stock_code,
    SUM(CASE WHEN description IS NULL OR TRIM(description) = '' THEN 1 ELSE 0 END) AS missing_description,
    SUM(CASE WHEN customer_id IS NULL OR TRIM(customer_id) = '' THEN 1 ELSE 0 END) AS missing_customer_id,
    SUM(CASE WHEN country IS NULL OR TRIM(country) = '' THEN 1 ELSE 0 END) AS missing_country
FROM online_retail;

-- ============================================================
-- 3. Quantity and price anomalies
-- ============================================================

SELECT
    COUNT(*) FILTER (WHERE quantity < 0) AS negative_quantity,
    COUNT(*) FILTER (WHERE quantity = 0) AS zero_quantity,
    COUNT(*) FILTER (WHERE unit_price < 0) AS negative_price,
    COUNT(*) FILTER (WHERE unit_price = 0) AS zero_price
FROM online_retail;


-- ============================================================
-- 4. Cancellations and their relationship to quantity
-- ============================================================

-- SELECT
--     COUNT(*) FILTER (
--         WHERE invoice_no LIKE 'C%'
--     ) AS cancellation_rows,

--     COUNT(*) FILTER (
--         WHERE invoice_no LIKE 'C%'
--           AND quantity < 0
--     ) AS cancellation_with_negative_quantity,

--     COUNT(*) FILTER (
--         WHERE invoice_no LIKE 'C%'
--           AND quantity >= 0
--     ) AS cancellation_without_negative_quantity,

--     COUNT(*) FILTER (
--         WHERE invoice_no NOT LIKE 'C%'
--           AND quantity < 0
--     ) AS negative_quantity_without_cancellation_code
-- FROM online_retail;

SELECT
    SUM(CASE WHEN invoice_no LIKE 'C%' THEN 1 ELSE 0 END) AS cancellation_rows,
    SUM(CASE WHEN invoice_no LIKE 'C%' AND quantity < 0 THEN 1 ELSE 0 END) AS cancellation_with_negative_quantity,
    SUM(CASE WHEN invoice_no LIKE 'C%' AND quantity >= 0 THEN 1 ELSE 0 END) AS cancellation_without_negative_quantity,
    SUM(CASE WHEN invoice_no NOT LIKE 'C%' AND quantity < 0 THEN 1 ELSE 0 END) AS negative_quantity_without_cancellation_code
FROM online_retail;

-- ============================================================
-- 5. Exact duplicate source rows
-- row_id is excluded because it is unique by construction
-- ============================================================

SELECT
    COUNT(*) AS duplicate_groups,
    COALESCE(SUM(duplicate_count - 1), 0) AS excess_duplicate_rows
FROM (
    SELECT
        invoice_no,
        stock_code,
        description,
        quantity,
        invoice_date,
        unit_price,
        customer_id,
        country,
        COUNT(*) AS duplicate_count
    FROM online_retail
    GROUP BY
        invoice_no,
        stock_code,
        description,
        quantity,
        invoice_date,
        unit_price,
        customer_id,
        country
    HAVING COUNT(*) > 1
) AS duplicates;


-- ============================================================
-- 6. Countries with the most transaction rows
-- ============================================================

SELECT
    country,
    COUNT(*) AS row_count,
    COUNT(DISTINCT invoice_no) AS invoice_count,
    COUNT(DISTINCT customer_id) AS customer_count
FROM online_retail
GROUP BY country
ORDER BY row_count DESC
LIMIT 10;


-- ============================================================
-- 7. Negative quantities without cancellation codes
-- ============================================================

SELECT
    invoice_no,
    stock_code,
    description,
    quantity,
    unit_price,
    customer_id,
    invoice_date,
    country
FROM online_retail
WHERE invoice_no NOT LIKE 'C%'
  AND quantity < 0
ORDER BY quantity
LIMIT 20;


-- ============================================================
-- 8. The two negative-price records
-- ============================================================

SELECT
    invoice_no,
    stock_code,
    description,
    quantity,
    unit_price,
    customer_id,
    invoice_date,
    country
FROM online_retail
WHERE unit_price < 0;


-- ============================================================
-- 9. How missing customer IDs overlap with other problems
-- ============================================================

SELECT
    COUNT(*) AS missing_customer_rows,

    SUM(
        CASE WHEN invoice_no LIKE 'C%'
             THEN 1 ELSE 0 END
    ) AS cancellation_rows,

    SUM(
        CASE WHEN quantity < 0
             THEN 1 ELSE 0 END
    ) AS negative_quantity_rows,

    SUM(
        CASE WHEN unit_price <= 0
             THEN 1 ELSE 0 END
    ) AS nonpositive_price_rows,

    SUM(
        CASE WHEN quantity > 0 AND unit_price > 0
             THEN 1 ELSE 0 END
    ) AS apparent_purchase_rows
FROM online_retail
WHERE customer_id IS NULL;


