# %%
import pandas as pd
from sqlalchemy import create_engine
import os

#%%
password = os.environ["POSTGRES_PASS"]

engine = create_engine(
    f"postgresql+psycopg2://postgres:{password}@localhost:5432/shop"
)

# with engine.connect() as connection:
#     print("Connected successfully!")



# query = """
# SELECT *
# FROM products;
# """

# products = pd.read_sql(query, engine)
# print(products.groupby("category")["price"].mean())

# %%
query = """
SELECT * 
FROM customers AS c
LEFT JOIN orders AS o
    ON c.customer_id = o.customer_id
LEFT JOIN order_items AS oi
    ON o.order_id = oi.order_id
LEFT JOIN products AS p
    ON oi.product_id = p.product_id;
"""

# %%
comb_df = pd.read_sql(query, engine)
comb_df["total"] = comb_df.quantity * comb_df.price
comb_df.sort_values("total")
totals = comb_df.groupby("product_name")["total"].sum().to_frame().sort_values("total", ascending=False)
totals.loc[totals["total"] > 100, "total"]

# %%
