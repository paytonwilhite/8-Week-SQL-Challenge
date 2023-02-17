CREATE SCHEMA dannys_diner;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');


-------------------------------------------------------------------------------------------------------------------
--Q1: What is the total amount each customer spent at the restaurant?

WITH all_sales AS
(
	SELECT s.customer_id, m.price
	FROM sales AS s
	JOIN menu AS m
	ON s.product_id = m.product_id
)
SELECT customer_id, sum(price) as total_spent
FROM all_sales
GROUP BY customer_id;


-------------------------------------------------------------------------------------------------------------------
--Q2: How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT(order_date)) as days_visited
FROM sales
GROUP BY customer_id;


-------------------------------------------------------------------------------------------------------------------
--Q3: What was the first item from the menu purchased by each customer?

WITH ordered_sales AS
(
	SELECT customer_id, order_date, product_name,
	DENSE_RANK() OVER(PARTITION BY sales.customer_id ORDER BY sales.order_date) AS rank
	FROM sales
	JOIN menu
	ON sales.product_id = menu.product_id
)
SELECT customer_id, product_name 
FROM ordered_sales
WHERE rank = 1
GROUP BY customer_id, product_name;


-------------------------------------------------------------------------------------------------------------------
--Q4: What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT TOP 1 (COUNT(sales.product_id)) as ct, sales.product_id, menu.product_name 
FROM sales
JOIN menu
ON sales.product_id = menu.product_id
GROUP BY menu.product_name, sales.product_id
ORDER BY ct DESC;

SELECT customer_id, COUNT(product_id) as times_purchased_ramen 
FROM sales
WHERE product_id = 3
GROUP BY customer_id;


-------------------------------------------------------------------------------------------------------------------
--Q5: Which item is the most popular for each customer?

WITH most_popular AS
(
	SELECT s.customer_id, COUNT(s.product_id) as ct, m.product_name,
	DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY COUNT(s.customer_id) DESC) AS rank
	FROM sales AS s
	JOIN menu AS m
	ON s.product_id = m.product_id
	GROUP BY s.customer_id, m.product_name
)
SELECT customer_id, ct, product_name 
FROM most_popular
WHERE RANK = 1;


-------------------------------------------------------------------------------------------------------------------
--Q6: Which item was purchased first by the customer after they became a member?

WITH member_sales AS
(
	SELECT s.customer_id, m.join_date, s.order_date, s.product_id,
	DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS rank
	FROM sales AS s
	JOIN members AS m
	ON s.customer_id = m.customer_id
	WHERE m.join_date <= s.order_date
)
SELECT ms.customer_id, ms.join_date, ms.order_date, menu.product_name
FROM member_sales as ms
JOIN menu 
ON ms.product_id = menu.product_id
WHERE ms.rank = 1;


-------------------------------------------------------------------------------------------------------------------
--Q7: Which item was purchased just before the customer became a member?

WITH member_sales_rev AS
(
	SELECT s.customer_id, m.join_date, s.order_date, s.product_id,
	DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS rank
	FROM sales AS s
	JOIN members AS m
	ON s.customer_id = m.customer_id
	WHERE m.join_date > s.order_date
)
SELECT msr.customer_id, menu.product_name
FROM member_sales_rev as msr
JOIN menu
ON msr.product_id = menu.product_id
WHERE msr.rank = 1;


-------------------------------------------------------------------------------------------------------------------
--Q8: What is the total items and amount spent for each member before they became a member?

WITH all_sales AS
(
	SELECT s.customer_id, s.order_date, s.product_id, m.price
	FROM sales as s
	JOIN menu as m
	ON s.product_id = m.product_id
)
SELECT a.customer_id, COUNT(DISTINCT(a.product_id)) as orders_made, SUM(a.price) as total_spent 
FROM all_sales as a
JOIN members as mems
ON a.customer_id = mems.customer_id
WHERE a.order_date < mems.join_date
GROUP BY a.customer_id;


-------------------------------------------------------------------------------------------------------------------
--Q9: If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH menu_points AS
(
	SELECT *,
		CASE
			WHEN product_id = 1 THEN price * 20
			ELSE price * 10
		END AS points
	FROM menu
)

SELECT s.customer_id, SUM(mp.points) as total_points
FROM sales as s
JOIN menu_points as mp
ON s.product_id = mp.product_id
GROUP BY s.customer_id;


-------------------------------------------------------------------------------------------------------------------
--Q10: In the first week after a customer joins the program (including their join date) they earn 2x points on all items,
--     not just sushi - how many points do customers A and B have at the end of January?

WITH dates_cte AS
(
	SELECT *,
		DATEADD(DAY, 6, join_date) AS last_day,
		EOMONTH('2021-01-31') AS end_month
	FROM members AS m
)
SELECT d.customer_id, 
	SUM(CASE
		WHEN menu.product_name = 'sushi' THEN 2 * 10 * menu.price
		WHEN sales.order_date BETWEEN d.join_date AND d.last_day THEN 2 * 10 * menu.price
		ELSE 10 * menu.price
		END) as points
FROM dates_cte as d
JOIN sales
	ON d.customer_id = sales.customer_id
JOIN menu
	ON sales.product_id = menu.product_id
WHERE sales.order_date < d.end_month
GROUP BY d.customer_id;