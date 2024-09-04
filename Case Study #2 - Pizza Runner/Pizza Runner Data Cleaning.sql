
SELECT * FROM customer_orders;
SELECT * FROM runner_orders;
SELECT * FROM runners;
SELECT * FROM pizza_names;
SELECT * FROM pizza_toppings;
SELECT * FROM pizza_recipes;


-- Cleaning the data:
-- There are NULL values in the customer_orders and runner_orders tables

UPDATE customer_orders SET exclusions = '' WHERE exclusions IS NULL;
UPDATE customer_orders SET extras = '' WHERE extras IS NULL;
UPDATE runner_orders SET cancellation = '' WHERE cancellation IS NULL;

-- In the runner_orders table, the pickup_time is VARCHAR(19). We need to change it to TIMESTAMP:
ALTER TABLE runner_orders MODIFY COLUMN pickup_time TIMESTAMP;

-- The distance should have a 'km', we'll add that:
UPDATE runner_orders
SET distance = CONCAT(distance, '', 'km')
WHERE distance NOT LIKE '% km';

-- The duration should have a 'minutes', we'll add that:
-- Replacing all unwanted substrings:
UPDATE runner_orders
SET duration = REPLACE(duration, 'utes', ''),
    duration = REPLACE(duration, 'u', ''),
    duration = REPLACE(duration, 'mi', ''),
    duration = REPLACE(duration, 'tem', ''),
    duration = TRIM(duration);

-- Adding 'minutes':
UPDATE runner_orders
SET duration = CONCAT(duration, ' minutes')
WHERE duration NOT LIKE '% minutes';

-- Making sure all null values remain unaffected:
UPDATE runner_orders
SET duration = NULL
WHERE duration = '';

UPDATE runner_orders
SET
    distance = CAST(REPLACE(distance, ' km', '') AS DECIMAL(10,2)),
    duration = CAST(REPLACE(duration, ' minutes', '') AS DECIMAL(10,2));