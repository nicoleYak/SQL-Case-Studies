SELECT * FROM sales;
SELECT * FROM members;
SELECT * FROM menu;

-- 1. What is the total amount each customer spent at the restaurant?

SELECT 
	customer_id,
    SUM(M.price) AS Total_spent
FROM sales S
JOIN menu M
ON S.product_id = M.product_id
GROUP BY customer_id;

-- 2. How many days has each customer visited the restaurant?

SELECT 
	customer_id,
	COUNT(DISTINCT DAY(order_date)) AS total_days
FROM sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?

WITH FirstOrders AS (
    SELECT 
        customer_id,
        product_id,
        order_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, product_id) AS rn
    FROM 
        Sales
)
SELECT 
    customer_id,
    product_id,
    order_date
FROM 
    FirstOrders
WHERE 
    rn = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT
	product_id,
    COUNT(order_date) AS times_purchased
FROM sales
GROUP BY product_id
ORDER BY times_purchased
LIMIT 1;

-- 5. Which item was the most popular for each customer?
-- Which item did every customer purchase the most?

WITH rankedproducts AS (
SELECT 
	sales.customer_id,
    sales.product_id,
    menu.product_name,
    COUNT(sales.product_id) AS times_purchased,
    ROW_NUMBER() OVER (PARTITION BY sales.customer_id ORDER BY COUNT(sales.product_id) DESC) AS rn
FROM sales
JOIN menu
ON sales.product_id = menu.product_id
GROUP BY 
        sales.customer_id, sales.product_id, menu.product_name
)

SELECT 
	customer_id,
    product_id,
    product_name,
    times_purchased
FROM rankedproducts
WHERE rn = 1;


-- 6. Which item was purchased first by the customer after they became a member?
-- identify the first order date for each customer after they joined
-- then join this result back to the sales table to get the product associated with that order.

WITH FirstOrderAfterJoin AS (
    SELECT
        s.customer_id,
        s.order_date,
        s.product_id,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS rn
    FROM
        sales s
    JOIN
        members m
    ON
        s.customer_id = m.customer_id
    WHERE
        s.order_date > m.join_date
)
SELECT
    m.customer_id AS CUSTOMER,
    m.join_date AS JOINED,
    f.order_date AS first_order,
    f.product_id,
    mm.product_name
FROM
    FirstOrderAfterJoin f
JOIN
	menu mm
ON 
	f.product_id = mm.product_id
JOIN
    members m
ON
    f.customer_id = m.customer_id
WHERE
    f.rn = 1;


-- 7. Which item was purchased just before the customer became a member?

WITH LastOrderBeforeJoin AS (
 SELECT
        s.customer_id,
        s.order_date,
        s.product_id,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS rn
    FROM
        sales s
    JOIN
        members m
    ON
        s.customer_id = m.customer_id
    WHERE
        s.order_date < m.join_date
)

SELECT
    m.customer_id AS CUSTOMER,
    m.join_date AS JOINED,
    L.order_date AS last_order,
    L.product_id,
    mm.product_name
FROM
    LastOrderBeforeJoin L
JOIN
	menu mm
ON 
	L.product_id = mm.product_id
JOIN
    members m
ON
    L.customer_id = m.customer_id
WHERE
    L.rn = 1;


-- 8. What is the total items and amount spent for each member before they became a member?
-- Total items bought
-- Total amount spent
-- Before joining

SELECT
	sales.customer_id,
    COUNT(sales.product_id) AS quantity,
    SUM(menu.price) AS total_spent
FROM sales
JOIN menu
ON sales.product_id = menu.product_id
JOIN members
ON sales.customer_id = members.customer_id
WHERE sales.order_date < members.join_date
GROUP BY sales.customer_id
ORDER BY sales.customer_id;


-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH Points as
(
SELECT *, 
CASE 
	WHEN product_id = 1 THEN price*20
	ELSE price*10
END AS Points
FROM Menu
)
SELECT 
	S.customer_id, 
	SUM(P.points) AS Points
FROM Sales S
JOIN Points p
ON p.product_id = S.product_id
GROUP BY S.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - 
-- how many points do customer A and B have at the end of January?


WITH Points AS (
SELECT 
	m.product_id, m.price, s.customer_id, mem.join_date,
CASE 
	WHEN s.order_date BETWEEN mem.join_date AND DATE_ADD(mem.join_date, INTERVAL 6 DAY) THEN price*20
	ELSE price*10
END AS Points
FROM Menu m
JOIN sales s
ON m.product_id = s.product_id
JOIN members mem
ON mem.customer_id = s.customer_id
)

SELECT
	customer_id,
    SUM(Points) AS TotalPoints
FROM Points
GROUP BY customer_id;


-- 11. Create a basic data table that Danny and his team can use to quickly derive insights without needing to join the underlying tables using SQL

SELECT 
	sales.customer_id AS CUSTOMER,
    sales.order_date AS DATE,
    menu.product_name AS PRODUCT,
    menu.price AS PRICE,
	CASE
	WHEN members.customer_id IS NOT NULL AND sales.order_date >= members.join_date THEN 'Y' 
    ELSE 'N'
END AS MEMBER
FROM sales
JOIN menu
ON sales.product_id = menu.product_id
LEFT JOIN members
ON sales.customer_id = members.customer_id
ORDER BY sales.customer_id, sales.order_date;


-- 12. Ranking of customer orders, NULL for orders that were placed before the customer became a member. 

SELECT 
    sales.customer_id AS CUSTOMER,
    sales.order_date AS DATE,
    menu.product_name AS PRODUCT,
    menu.price AS PRICE,
    CASE 
        WHEN members.customer_id IS NOT NULL AND sales.order_date >= members.join_date THEN 'Y'
        ELSE 'N'
    END AS MEMBER,
    CASE
        WHEN members.customer_id IS NOT NULL AND sales.order_date >= members.join_date THEN 
            DENSE_RANK() OVER(PARTITION BY sales.customer_id ORDER BY sales.order_date)
        ELSE 'null'
    END AS rnk
FROM 
    sales
JOIN 
    menu
ON 
    sales.product_id = menu.product_id
LEFT JOIN 
    members
ON 
    sales.customer_id = members.customer_id
ORDER BY 
    sales.customer_id, sales.order_date;
