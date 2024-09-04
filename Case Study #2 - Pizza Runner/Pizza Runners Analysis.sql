
SELECT * FROM customer_orders;
SELECT * FROM runner_orders;
SELECT * FROM runners;
SELECT * FROM pizza_names;
SELECT * FROM pizza_toppings;
SELECT * FROM pizza_recipes;

## PIZZA METRICS Q'S:

-- 1. How many pizzas were ordered?

SELECT COUNT(order_id) FROM customer_orders;

-- 2. How many unique customer orders were made?

SELECT COUNT(distinct order_id) FROM customer_orders;

-- 3. How many successful orders were delivered by each runner?

SELECT COUNT(order_id) FROM runner_orders
WHERE pickup_time IS NOT NULL;

-- 4. How many of each type of pizza was delivered?

SELECT 
	c.pizza_id,
	COUNT(r.order_id) AS pizzas_delivered
FROM customer_orders c
JOIN runner_orders r
ON c.order_id = r.order_id
WHERE cancellation = ''
GROUP BY c.pizza_id;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?

SELECT 
	customer_id,
    pizza_name,
    COUNT(pizza_id) AS total_pizzas_ordered
FROM customer_orders
JOIN pizza_names
USING (pizza_id)
GROUP BY customer_id, pizza_name
ORDER BY customer_id, pizza_name;

-- 6. What was the maximum number of pizzas delivered in a single order?

SELECT
	order_id,
	pizzas_count
FROM (
	SELECT
		c.order_id,
		COUNT(pizza_id) AS pizzas_count
	FROM customer_orders c
	JOIN runner_orders r
	USING (order_id)
	WHERE pickup_time IS NOT NULL
	GROUP BY c.order_id
) AS pizza_count

ORDER BY 
    pizzas_count DESC
LIMIT 1;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

WITH pizza_change AS (
	SELECT
    customer_id,
    CASE
		WHEN exclusions = '' AND extras = '' THEN 0
        ELSE 1
        END AS change_in_order
	FROM customer_orders 
    JOIN runner_orders
    USING (order_id)
	WHERE pickup_time IS NOT NULL
)

SELECT 
	customer_id,
    SUM(CASE WHEN change_in_order = 0 THEN 1 ELSE 0 END) AS no_change,
    SUM(CASE WHEN change_in_order = 1 THEN 1 ELSE 0 END) AS pizzas_changed
FROM pizza_change
GROUP BY customer_id;


-- 8. How many pizzas were delivered that had both exclusions and extras?


WITH pizza_change AS (
	SELECT
    customer_id,
    CASE
		WHEN exclusions != '' AND extras != '' THEN 1
        ELSE 0
        END AS change_in_order
	FROM customer_orders 
    JOIN runner_orders
    USING (order_id)
	WHERE pickup_time IS NOT NULL
)

SELECT 
	customer_id,
    SUM(CASE WHEN change_in_order = 1 THEN 1 ELSE 0 END) AS pizzas_changed
FROM pizza_change
GROUP BY customer_id;


-- 9. What was the total volume of pizzas ordered for each hour of the day?

SELECT 
	CONCAT(HOUR(order_time), ":00") AS order_hour,
    COUNT(pizza_id) AS total_volume
FROM customer_orders
GROUP BY order_hour
ORDER BY order_hour;

-- 10. What was the volume of orders for each day of the week?

SELECT 
	DAYNAME(order_time) AS order_day,
    COUNT(pizza_id) AS total_volume
FROM customer_orders
GROUP BY order_day
ORDER BY order_day;


## RUNNER AND CUSTOMER EXPERIENCE Q'S:

-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

SELECT 
    DATE_ADD('2021-01-01', INTERVAL FLOOR(DATEDIFF(registration_date, '2021-01-01') / 7) * 7 DAY) AS week_start,
    COUNT(*) AS num_runners_signed_up
FROM Runners
GROUP BY week_start
ORDER BY week_start;


-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

SELECT
    runner_id,
    CONCAT(ROUND(AVG(TIMESTAMPDIFF(SECOND, order_time, pickup_time) / 60), 2),' ', "Minutes") AS average_time_to_pickup
FROM customer_orders
JOIN runner_orders USING (order_id)
GROUP BY runner_id
ORDER BY runner_id;


-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

-- Calculating the time it takes to prepare the pizzas:

SELECT
	order_id,
    COUNT(pizza_id) AS num_pizzas,
    TIMESTAMPDIFF(MINUTE, order_time, pickup_time) AS prep_time
FROM customer_orders
JOIN runner_orders
USING (order_id)
WHERE pickup_time > order_time
GROUP BY order_id
ORDER BY order_id;

-- Analyzing the correlation between number of pizzas ordered and prep time:

SELECT 
    num_pizzas,
    ROUND(AVG(prep_time),2) AS avg_prep_time
FROM (
    SELECT 
        COUNT(pizza_id) AS num_pizzas,
        TIMESTAMPDIFF(MINUTE, order_time, pickup_time) AS prep_time
    FROM customer_orders
    JOIN runner_orders USING (order_id)
    WHERE pickup_time > order_time
    GROUP BY order_id
) AS derived_table
GROUP BY num_pizzas
ORDER BY num_pizzas;

-- The results show that the average prep time increases with the number of pizzas ordered, which suggests a relationship.
-- This correlation is positive. The more pizzas, the higher the prep time.

-- 4. What was the average distance travelled for each customer?

SELECT
	customer_id,
    ROUND(AVG(CAST(REPLACE(distance, ' km', '') AS DECIMAL(10,2))), 2) AS average_distance
FROM runner_orders
JOIN customer_orders
USING (order_id)
WHERE pickup_time IS NOT NULL
GROUP BY customer_id
ORDER BY customer_id;
    
-- 5. What was the difference between the longest and shortest delivery times for all orders?

SELECT
    CONCAT(MAX(duration) - MIN(duration), ' ', "Minutes") AS delivery_time_difference
FROM runner_orders
WHERE duration IS NOT NULL;


-- 6. What was the average speed for each runner for each delivery?

-- Remove the 'km' and the 'minutes'
-- Convert the duration to hours
-- Distance / duration

WITH converted AS (
	SELECT
    runner_id,
    order_id,
    CAST(REPLACE(distance, ' km', '') AS DECIMAL(10,2)) AS distance,
    (CAST(REPLACE(duration, ' minutes', '') AS DECIMAL(10,2))) / 60 AS duration
FROM runner_orders
WHERE duration IS NOT NULL
)

SELECT 
	runner_id,
    order_id,
    CONCAT(ROUND(AVG(distance / duration),2), ' ', "km/h") AS average_speed
FROM converted
GROUP BY runner_id, order_id
ORDER BY runner_id, order_id;


-- 7. What is the successful delivery percentage for each runner?

-- Calculate total deliveries
-- Calculate Successful Deliveries
-- Calculate Percentage

WITH delivery_status AS (
	SELECT
    runner_id,
    CASE
		WHEN cancellation = '' THEN 1
        ELSE 0 END AS success_flag
	FROM runner_orders
)	
SELECT
	runner_id,
    ROUND((SUM(CASE WHEN success_flag = 1 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS successful_delivery_percentage
FROM 
    delivery_status
JOIN
	runner_orders
USING (runner_id)
GROUP BY runner_id;
    

## INGREDIENT OPTIMIZATION Q'S:

-- 1. What are the standard ingredients for each pizza?

WITH RECURSIVE ToppingSplit AS (
    -- Initial extraction of the first topping
    SELECT 
        pizza_id,
        CAST(SUBSTRING_INDEX(toppings, ',', 1) AS UNSIGNED) AS topping_id,
        SUBSTRING(toppings, LOCATE(',', toppings) + 1) AS remaining_toppings
    FROM 
        pizza_recipes
    WHERE 
        toppings IS NOT NULL

    UNION ALL

    -- Recursive part: continue extracting the next topping
    SELECT 
        pizza_id,
        CAST(SUBSTRING_INDEX(remaining_toppings, ',', 1) AS UNSIGNED) AS topping_id,
        CASE 
            WHEN LOCATE(',', remaining_toppings) = 0 THEN NULL
            ELSE SUBSTRING(remaining_toppings, LOCATE(',', remaining_toppings) + 1)
        END AS remaining_toppings
    FROM 
        ToppingSplit
    WHERE 
        remaining_toppings IS NOT NULL
)

SELECT 
    n.pizza_name,
    t.topping_name
FROM ToppingSplit r
JOIN pizza_toppings t 
ON r.topping_id = t.topping_id
JOIN pizza_names n
ON n.pizza_id = r.pizza_id
ORDER BY n.pizza_name;


-- 2. What was the most commonly added extra?

-- Creating a utility table with numbers to help split the comma-separated values:
CREATE TABLE numbers (
  num INT PRIMARY KEY
);

INSERT INTO numbers VALUES
( 1 ), ( 2 ), ( 3 ), ( 4 ), ( 5 ), ( 6 ), ( 7 ), ( 8 ), ( 9 ), ( 10 ),( 11 ), ( 12 ), ( 13 ), ( 14 );

-- The CTE extracts individual toppings from a concatenated string of all extras and counts how many times each topping was added.
WITH CTE AS (

SELECT 
	n.num, 
	SUBSTRING_INDEX(SUBSTRING_INDEX(all_tags, ',', num), ',', -1) as one_tag
FROM (
  SELECT
    GROUP_CONCAT(extras SEPARATOR ',') AS all_tags,
    LENGTH(GROUP_CONCAT(extras SEPARATOR ',')) - LENGTH(REPLACE(GROUP_CONCAT(extras SEPARATOR ','), ',', '')) + 1 AS count_tags
  FROM customer_orders
) t

JOIN numbers n
ON n.num <= t.count_tags
)
-- The main query joins this extracted data with the pizza_toppings table to return the topping name and its frequency as an extra
SELECT 
	one_tag AS Extras,
	pizza_toppings.topping_name AS ExtraTopping, 
    COUNT(one_tag) as frequency
FROM CTE
INNER JOIN pizza_toppings
ON pizza_toppings.topping_id = cte.one_tag
WHERE one_tag != 0
GROUP BY one_tag;


-- 3. What was the most common exclusion?

WITH CTE AS (

SELECT 
	n.num, 
	SUBSTRING_INDEX(SUBSTRING_INDEX(all_tags, ',', num), ',', -1) as one_tag
FROM (
  SELECT
    GROUP_CONCAT(exclusions SEPARATOR ',') AS all_tags,
    LENGTH(GROUP_CONCAT(exclusions SEPARATOR ',')) - LENGTH(REPLACE(GROUP_CONCAT(exclusions SEPARATOR ','), ',', '')) + 1 AS count_tags
  FROM customer_orders
) t

JOIN numbers n
ON n.num <= t.count_tags
)
-- The main query joins this extracted data with the pizza_toppings table to return the topping name and its frequency as an extra
SELECT 
	one_tag AS exclusions,
	pizza_toppings.topping_name AS ExcludedTopping, 
    COUNT(one_tag) as frequency
FROM CTE
INNER JOIN pizza_toppings
ON pizza_toppings.topping_id = cte.one_tag
WHERE one_tag != 0
GROUP BY one_tag;


-- 4. Generate an order item for each record in the customers_orders table

SELECT 
	customer_orders.order_id, 
    customer_orders.pizza_id, 
    pizza_names.pizza_name, 
    customer_orders.exclusions, 
    customer_orders.extras, 
CASE
WHEN customer_orders.pizza_id = 1 AND (exclusions IS NULL OR exclusions=0) AND (extras IS NULL OR extras=0) THEN 'Meat Lovers'
WHEN customer_orders.pizza_id = 2 AND (exclusions IS NULL OR exclusions=0) AND (extras IS NULL OR extras=0) THEN 'Veg Lovers'
WHEN customer_orders.pizza_id = 2 AND (exclusions =4 ) AND (extras IS NULL OR extras=0) THEN 'Veg Lovers - Exclude Cheese'
WHEN customer_orders.pizza_id = 1 AND (exclusions =4 ) AND (extras IS NULL OR extras=0) THEN 'Meat Lovers - Exclude Cheese'
WHEN customer_orders.pizza_id=1 AND (exclusions LIKE '%3%' or exclusions =3) AND (extras IS NULL OR extras=0) THEN 'Meat Lovers - Exclude Beef'
WHEN customer_orders.pizza_id =1 AND (exclusions IS NULL OR exclusions=0) AND (extras LIKE '%1%' or extras =1) THEN 'Meat Lovers - Extra Bacon'
WHEN customer_orders.pizza_id =2 AND (exclusions IS NULL OR exclusions=0) AND (extras LIKE '%1%' or extras =1) THEN 'Veg Lovers - Extra Bacon'
WHEN customer_orders.pizza_id=1 AND (exclusions LIKE '1, 4' ) AND (extras LIKE '6, 9') THEN 'Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers'
WHEN customer_orders.pizza_id=1 AND (exclusions LIKE '2, 6' ) AND (extras LIKE '1, 4') THEN 'Meat Lovers - Exclude BBQ Sauce,Mushroom - Extra Bacon, Cheese'
WHEN customer_orders.pizza_id=1 AND (exclusions =4) AND (extras LIKE '1, 5') THEN 'Meat Lovers - Exclude Cheese - Extra Bacon, Chicken'
END AS OrderItem
FROM customer_orders
INNER JOIN pizza_names
ON pizza_names.pizza_id = customer_orders.pizza_id;


## PRICING AND RATING:

/* 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes — 
how much money has Pizza Runner made so far if there are no delivery fees? */

-- Meat lovers pizza - 12$
-- Vegetarian pizza - 10$
-- No charges for changes
-- No delivery fees

WITH pizza_count AS (
	SELECT
		SUM(CASE WHEN pizza_id = 1 THEN 1 ELSE 0 END) AS meat_pizzas,
		SUM(CASE WHEN pizza_id = 2 THEN 1 ELSE 0 END) AS veg_pizzas
	FROM customer_orders
    JOIN runner_orders
    USING (order_id)
    WHERE runner_orders.distance IS NOT NULL
)

SELECT
    (meat_pizzas * 12) AS total_earned_meat,
    (veg_pizzas * 10) AS total_earned_veg,
    SUM((meat_pizzas * 12) + (veg_pizzas * 10)) AS total_earned
FROM pizza_count;
    

-- 2. What if there was an additional $1 charge for any pizza extras?
    
WITH pizza_sales AS (
    SELECT
        pizza_id,
        COUNT(*) AS pizza_count,
        SUM(CASE WHEN extras IS NOT NULL AND extras <> '' THEN LENGTH(extras) - LENGTH(REPLACE(extras, ',', '')) + 1 ELSE 0 END) AS extras_count
    FROM customer_orders
    JOIN runner_orders
    USING (order_id)
    WHERE runner_orders.distance IS NOT NULL
    GROUP BY pizza_id
)

SELECT
    SUM(CASE WHEN pizza_id = 1 THEN pizza_count * 12 + extras_count ELSE 0 END) AS total_earned_meat,
    SUM(CASE WHEN pizza_id = 2 THEN pizza_count * 10 + extras_count ELSE 0 END) AS total_earned_veg,
    (SUM(CASE WHEN pizza_id = 1 THEN pizza_count * 12 + extras_count ELSE 0 END) + SUM(CASE WHEN pizza_id = 2 THEN pizza_count * 10 + extras_count ELSE 0 END)) AS total_earned
FROM pizza_sales;


/* 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, 
how would you design an additional table for this new dataset - generate a schema for this new table and insert your own 
data for ratings for each successful customer order between 1 to 5. */

-- omitting the orders that were cancelled
CREATE TABLE ratings (
order_id integer,
rating integer
);

INSERT INTO ratings (order_id, rating)
VALUES
(1,3),
(2,5),
(3,3),
(4,1),
(5,5),
(7,3),
(8,4),
(10,3);

SELECT * FROM ratings;


/* 4. Using your newly generated table - 
can you join all of the information together to form a table which has the 
following information for successful deliveries?

customer_id
order_id
runner_id
rating
order_time
pickup_time
Time between order and pickup
Delivery duration
Average speed
Total number of pizzas

*/


SELECT 
	customer_orders.customer_id,
	customer_orders.order_id,
	runner_orders.runner_id,
	ratings.rating,
	customer_orders.order_time,
	runner_orders.pickup_time,
	timestampdiff(minute, order_time, pickup_time) AS time_difference,
	runner_orders.duration,
	round(avg(runner_orders.distance*60/runner_orders.duration),1) as avg_speed,
	COUNT(pizza_id) AS pizzas_ordered
FROM
	customer_orders
JOIN 
	ratings USING (order_id)
JOIN 
	runner_orders USING (order_id)
WHERE 
	runner_orders.distance IS NOT NULL
GROUP BY 
	customer_orders.customer_id, customer_orders.order_id, runner_orders.runner_id,
	ratings.rating, customer_orders.order_time, runner_orders.pickup_time, time_difference, runner_orders.duration
ORDER BY 
	customer_id;


/* If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras 
and each runner is paid $0.30 per kilometre traveled - 
how much money does Pizza Runner have left over after these deliveries? */


WITH pizza_count AS (
	SELECT
		order_id,
		SUM(CASE WHEN pizza_id = 1 THEN 1 ELSE 0 END) AS meat_pizzas,
		SUM(CASE WHEN pizza_id = 2 THEN 1 ELSE 0 END) AS veg_pizzas
	FROM customer_orders
    JOIN runner_orders
    USING (order_id)
    WHERE runner_orders.distance IS NOT NULL
),

runner_paid AS (
	SELECT 	
        SUM(distance * 0.3) AS amount_paid
	FROM runner_orders
    WHERE distance IS NOT NULL
)

SELECT
    (meat_pizzas * 12) AS total_earned_meat,
    (veg_pizzas * 10) AS total_earned_veg,
    (meat_pizzas * 12) + (veg_pizzas * 10) AS total_earned,
    amount_paid AS total_paid_to_runners,
    ((meat_pizzas * 12) + (veg_pizzas * 10)) - rp.amount_paid AS remaining_amount
FROM pizza_count pc
CROSS JOIN runner_paid rp;






