# Part 3 SQL learning notes

## Data grain

- What does one row represent in `online_retail`?
- A particular item in a purchase
- One row represents **an invoice line** for one product, including the quantity of that product.

-  What does one row represent in `online_retail_analytical`?
- Deduplicated and cleaned items from purchases
- One row represents a deduplicated invoice line associated with an identified customer, 
classified as a purchase, return/cancellation, or other record.

- What does one row represent in `customer_snapshot_2011_09_01`?
- A customer that has purchased something before the snapshot data
- One row represents a customer who purchased before the snapshot date, together with 
features calculated from their earlier purchases and a target indicating whether they 
purchased during September.


## Tables and views

- Does a normal view store another copy of the rows?
- No, it keeps the query in memory in an easily accessible, stable form.

## Common table expressions

- Why did we use two CTEs inside the customer-snapshot view?
- To make the join of the two tables more logical and easy to follow. 

- Why can’t those CTEs be queried independently afterward?
- Because CTEs are not stored in memory

## Aggregation and GROUP BY

## LEFT JOIN and missing matches

## COALESCE

## Temporal cutoffs and data leakage