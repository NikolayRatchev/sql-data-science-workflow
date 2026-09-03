CREATE TABLE IF NOT EXISTS online_retail (
    row_id          BIGSERIAL PRIMARY KEY,
    invoice_no      TEXT NOT NULL,
    stock_code      TEXT NOT NULL,
    description     TEXT,
    quantity        INTEGER NOT NULL,
    invoice_date    TIMESTAMP NOT NULL,
    unit_price      NUMERIC(12, 2) NOT NULL,
    customer_id     TEXT,
    country         TEXT NOT NULL
);