INSERT INTO customers (customer_id, name, age, city)
VALUES
    (1, 'Alice', 34, 'Sofia'),
    (2, 'Boris', 27, 'Plovdiv'),
    (3, 'Clara', 41, 'Varna'),
    (4, 'Daniel', 29, 'Sofia'),
    (5, 'Elena', 36, 'Ruse');

INSERT INTO products (product_id, product_name, category, price)
VALUES
    (1, 'Coffee Mug', 'Kitchen', 12.50),
    (2, 'Notebook', 'Stationery', 8.90),
    (3, 'Headphones', 'Electronics', 79.99),
    (4, 'Keyboard', 'Electronics', 54.90),
    (5, 'Water Bottle', 'Kitchen', 19.50);

INSERT INTO orders (order_id, customer_id, order_date)
VALUES
    (101, 1, '2026-01-15'),
    (102, 1, '2026-02-03'),
    (103, 2, '2026-02-10'),
    (104, 3, '2026-02-18'),
    (105, 3, '2026-03-01'),
    (106, 4, '2026-03-05'),
    (107, 1, '2026-03-12');