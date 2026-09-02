# install.packages(c("DBI", "RPostgres", "dplyr", "dbplyr"))

library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)

Sys.getenv("POSTGRES_PASS")

# connect to `shop` database
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = "shop",
  host = "localhost",
  port = 5432,
  user = "postgres",
  password = Sys.getenv("POSTGRES_PASS")
)


# access the `products` table
products <- tbl(con, "products")

products

class(products)

# write the query with dbplyr
avg_prices <- products |>
  group_by(category) |>
  summarise(avg_price = mean(price, na.rm = TRUE))

# show the query in SQL
show_query(avg_prices)

# create local table
avg_prices_local <- collect(avg_prices)

class(avg_prices_local)
