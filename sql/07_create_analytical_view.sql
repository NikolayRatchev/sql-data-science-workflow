-- Create a customer-level analytical source while preserving
-- the original imported data in online_retail.

-- This view applies four rules:

-- Keeps one copy of each exact duplicate.
-- Retains only identified customers.
-- Removes negative-price accounting adjustments.
-- Labels purchases and returns without deleting the returns.

CREATE OR REPLACE VIEW online_retail_analytical AS

WITH ranked_rows AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                invoice_no,
                stock_code,
                description,
                quantity,
                invoice_date,
                unit_price,
                customer_id,
                country
            ORDER BY row_id
        ) AS duplicate_rank
    FROM online_retail
)

SELECT
    row_id,
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,

    quantity * unit_price AS signed_line_value,

    (
        quantity > 0
        AND unit_price > 0
        AND invoice_no NOT LIKE 'C%'
    ) AS is_purchase,

    (
        quantity < 0
        OR invoice_no LIKE 'C%'
    ) AS is_return_or_cancellation

FROM ranked_rows
WHERE duplicate_rank = 1
  AND customer_id IS NOT NULL
  AND TRIM(customer_id) <> ''
  AND unit_price >= 0;


-- ============================================================
-- Validate analytical view
-- ============================================================


SELECT
    COUNT(*) AS analytical_rows,
    COUNT(DISTINCT invoice_no) AS invoices,
    COUNT(DISTINCT customer_id) AS customers,

    COUNT(*) FILTER (
        WHERE is_purchase
    ) AS purchase_rows,

    COUNT(*) FILTER (
        WHERE is_return_or_cancellation
    ) AS return_or_cancellation_rows,

    COUNT(*) FILTER (
        WHERE NOT is_purchase
          AND NOT is_return_or_cancellation
    ) AS other_rows,

    COUNT(*) FILTER (
        WHERE unit_price = 0
    ) AS zero_price_rows,

    COUNT(*) FILTER (
        WHERE description IS NULL
           OR TRIM(description) = ''
    ) AS missing_description_rows
FROM online_retail_analytical;