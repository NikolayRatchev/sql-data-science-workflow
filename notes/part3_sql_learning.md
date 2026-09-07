# Part 3 SQL learning notes

## Data grain

Data grain is the level at which the data are represented in a specific table 
(e.g., individual, product, etc.). 

In this project, 

- One row in `online_retail` represents **an invoice line** for one product, 
including the quantity of that product.

- One row in `online_retail_analytical` represents a deduplicated invoice line 
associated with an identified customer, 
classified as a purchase, return/cancellation, or other record.

- One row in `customer_snapshot_2011_09_01`  represents a customer who purchased 
before the snapshot date, together with features calculated from their earlier 
purchases and a target indicating whether they purchased during September.


## Tables and views

A normal view stores a reusable query definition in the database, 
not another copy of its result rows.

## Common table expressions

We used two CTEs inside the customer-snapshot view. The aim was to
separate the historical feature calculation and future target calculation 
into two named intermediate result sets, making their join easier to understand.

Those CTEs cannot be queried independently afterward.
A CTE exists only within the SQL statement that immediately follows its WITH clause. 
It does not become a persistent database object.

## WHERE, aggregate FILTER, and HAVING
- `WHERE` filters input rows before grouping.
- `FILTER` chooses which rows contribute to a particular aggregate.
- `HAVING` filters groups after aggregation.

## Aggregation and GROUP BY

`GROUP BY` divides rows into groups that share the same value in one or more
columns. Aggregate functions such as `SUM()`, `MAX()`, and `COUNT()` then
produce one result for each group.

In this project, rows in `online_retail_analytical` initially represent invoice
lines. Grouping by `customer_id` changes the grain to one row per customer.

Every selected column must either appear in `GROUP BY` or be summarized by an
aggregate function. Therefore, `customer_id` appears in `GROUP BY`, while
`invoice_date`, `invoice_no`, and the numeric variables are used inside
aggregate functions.
## `LEFT JOIN` and missing matches

In this project, `customer_features` was on the left side 
while `target_customers` on the right side of the join. 
`LEFT JOIN` ensured retaining every customer from `customer_features`.
`INNER JOIN` would have removed customers with no purchases in the 30 days
following the snapshot date. 

## COALESCE

`COALESCE` is somewhat like an if/else operation, but it does not test 
whether a general condition is false. It returns the first non-null argument

In this project, 
we used it to replace missing values with 0 for customers who did not purchase in September. 
The missing values were produced by `LEFT JOIN`: the customers who did not purchase were simply
absent from `target_customers`. 

`COALESCE(target, 0)` returns the existing target value when it is not null and
returns `0` otherwise. Here, a null match has a specific meaning: the eligible
customer was absent from `target_customers` because they made no valid purchase
during September.

## Temporal cutoffs and data leakage

Features used transactions before 1 September:

`invoice_date < DATE '2011-09-01'`

The target used transactions from 1 September inclusive to 1 October exclusive:

`invoice_date >= DATE '2011-09-01'`
and
`invoice_date < DATE '2011-10-01'`

The two periods touch but do not overlap. If transactions from September were
used to calculate the features, the model would receive information from the
period it is supposed to predict, causing data leakage.