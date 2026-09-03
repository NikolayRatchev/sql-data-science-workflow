# %%
import os
from pathlib import Path

import pandas as pd
from sqlalchemy import URL, create_engine, func, select, Table, MetaData


# %%
# Locate the Excel file relative to this script
project_root = Path(__file__).resolve().parent.parent
data_path = project_root / "data" / "raw" / "Online Retail.xlsx"

if not data_path.exists():
    raise FileNotFoundError(f"Dataset not found: {data_path}")


# %%
# Create the database connection
connection_url = URL.create(
    drivername="postgresql+psycopg2",
    username="postgres",
    password=os.environ["POSTGRES_PASS"],
    host="localhost",
    port=5432,
    database="shop",
)

engine = create_engine(connection_url)


# %%
# Read the Excel dataset
retail = pd.read_excel(data_path)

print(retail.head())
print(retail.shape)
print(retail.dtypes)


# %%
# Rename columns to SQL-friendly snake_case names
retail = retail.rename(
    columns={
        "InvoiceNo": "invoice_no",
        "StockCode": "stock_code",
        "Description": "description",
        "Quantity": "quantity",
        "InvoiceDate": "invoice_date",
        "UnitPrice": "unit_price",
        "CustomerID": "customer_id",
        "Country": "country",
    }
)


# %%
# Convert identifiers to strings
retail["invoice_no"] = retail["invoice_no"].astype("string")
retail["stock_code"] = retail["stock_code"].astype("string")

# Excel may read customer IDs as floating-point numbers.
# Convert them to nullable integers first to avoid values such as "17850.0".
retail["customer_id"] = (
    pd.to_numeric(retail["customer_id"], errors="coerce")
    .astype("Int64")
    .astype("string")
)

print(retail.head())
print(retail.dtypes)
print(retail.isna().sum())


# %%
# Check whether the destination table is empty before importing
metadata = MetaData()
online_retail = Table(
    "online_retail",
    metadata,
    autoload_with=engine,
)

with engine.connect() as connection:
    existing_rows = connection.scalar(
        select(func.count()).select_from(online_retail)
    )

if existing_rows:
    raise RuntimeError(
        f"online_retail already contains {existing_rows:,} rows. "
        "Import stopped to avoid duplicates."
    )


# %%
# Insert the data in manageable batches
retail.to_sql(
    name="online_retail",
    con=engine,
    if_exists="append",
    index=False,
    chunksize=5_000,
    method="multi",
)

print(f"Imported {len(retail):,} rows into online_retail.")


# %%
# Verify the resulting row count
with engine.connect() as connection:
    imported_rows = connection.scalar(
        select(func.count()).select_from(online_retail)
    )

print(f"PostgreSQL row count: {imported_rows:,}")
