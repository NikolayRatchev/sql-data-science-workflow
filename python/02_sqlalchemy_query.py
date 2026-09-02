# %%
import os

from sqlalchemy import create_engine, MetaData, Table, select, func


# %%
password = os.environ["POSTGRES_PASS"]

engine = create_engine(
    f"postgresql+psycopg2://postgres:{password}@localhost:5432/shop"
)

# %%
metadata = MetaData()

products = Table(
    "products",
    metadata,
    autoload_with=engine
)

# inspect table
print(products.columns.keys())

# %%
# construct the query in Python
query = (
    select(
        products.c.category,
        func.avg(products.c.price).label("avg_price")
    )
    .group_by(products.c.category)
)

print(query)

# %%
with engine.connect() as connection:
    result = connection.execute(query)

    for row in result:
        print(row)


# %%
