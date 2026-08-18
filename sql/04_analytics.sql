-- Which customers have placed orders?
SELECT customers.customer_id, name, order_id FROM customers JOIN orders
ON customers.customer_id = orders.customer_id
ORDER BY customers.customer_id, order_id;

-- How much money has each customer spent?
