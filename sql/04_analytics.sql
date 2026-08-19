-- Which customers have placed orders?
SELECT customers.customer_id, name, order_id FROM customers JOIN orders
ON customers.customer_id = orders.customer_id
ORDER BY customers.customer_id, order_id;

-- Which customers have placed orders? (alternative solution)
SELECT
    c.customer_id,
    c.name,
    o.order_id
FROM customers AS c
JOIN orders AS o
    ON c.customer_id = o.customer_id
ORDER BY c.customer_id, o.order_id;

-- Which customers have not placed any orders?
SELECT
    c.customer_id,
    c.name,
    o.order_id
FROM customers AS c
JOIN orders AS o
    ON c.customer_id = o.customer_id
ORDER BY c.customer_id, o.order_id;



-- How much money has each customer spent?
SELECT DISTINCT c.customer_id, c.name,
COALESCE(
    SUM(oi.quantity * p.price) 
	    OVER(PARTITION BY c.customer_id), 
	0
) AS total_spent
FROM customers AS c
LEFT JOIN orders AS o
    ON c.customer_id = o.customer_id
LEFT JOIN  order_items AS oi
    ON o.order_id = oi.order_id
LEFT JOIN  products AS p
    ON oi.product_id = p.product_id
ORDER BY total_spent DESC;


-- How much money has each customer spent? (ALT)
SELECT
    c.customer_id,
    c.name,
    SUM(oi.quantity * p.price) AS total_spent
FROM customers AS c
LEFT JOIN orders AS o
    ON c.customer_id = o.customer_id
LEFT JOIN order_items AS oi
    ON o.order_id = oi.order_id
LEFT JOIN products AS p
    ON oi.product_id = p.product_id
GROUP BY c.customer_id, c.name
ORDER BY total_spent DESC;