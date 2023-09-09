-- Query 01: calculate total visit, pageview, transaction for Jan, Feb and March 2017 (order by month)

SELECT  
      FORMAT_DATE('%Y%m',parse_date('%Y%m%d',date)) AS month, 
      SUM(totals.visits) AS visits,
      SUM(totals.pageviews) AS pagaviews,
      SUM(totals.transactions) AS transactions
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
where _table_suffix BETWEEN '0101' AND'0331'
GROUP BY month
ORDER BY month;


-- Query 02: Bounce rate per traffic source in July 2017 (Bounce_rate = num_bounce/total_visit) (order by total_visit DESC)

SELECT source,
      total_bounces,
      total_visits,
      ROUND((total_bounces/total_visits*100),2) AS bounces_rate
FROM (SELECT 
        trafficSource.source,
        SUM(totals.bounces) AS total_bounces,
        SUM(totals.visits) AS total_visits
    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
    GROUP BY trafficSource.source) AS sub
    
GROUP BY source, total_bounces, total_visits
ORDER BY total_visits DESC;

-- Query 3: Revenue by traffic source by week, by month in June 2017

-- Get data by week
(SELECT  'Week' as time_type,
        FORMAT_DATE('%Y-w%W',parse_date('%Y%m%d',date)) AS time_June,
        trafficSource.source,
        SUM(productRevenue)/1000000 AS revenue_miliion
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*` ,
UNNEST (hits) hits,
UNNEST (hits.product) AS product
GROUP BY trafficSource.source,time_June
ORDER BY source)
-- Get data by month, then Union 1 table
UNION ALL
(SELECT  'Month' as time_type,
        FORMAT_DATE('%Y-m%m',parse_date('%Y%m%d',date)) AS time_June,
        trafficSource.source,
        SUM(productRevenue)/1000000 AS revenue_miliion
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*` ,
UNNEST (hits) hits,
UNNEST (hits.product) AS product
GROUP BY trafficSource.source,time_June)
ORDER BY source;

-- Query 04: Average number of pageviews by purchaser type (purchasers vs non-purchasers) in June, July 2017.

-- create a CTE to calcualate total pageviews, ID of customer who purchase product
WITH purchaser AS (
  SELECT 
     totals.pageviews,
     fullVisitorId,
     FORMAT_DATE('%Y%m',parse_date('%Y%m%d',date)) AS month
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
UNNEST (hits) hits,
UNNEST (hits.product) AS product
WHERE (_table_suffix BETWEEN '0601' AND'0731') AND
      (productRevenue IS NOT NULL) AND
      (totals.transactions>=1)
),
-- create a CTE to calcualate total pageviews, ID of customer who didn't purchase product
non_purchaser AS (
 SELECT 
     totals.pageviews,
     fullVisitorId,
     FORMAT_DATE('%Y%m',parse_date('%Y%m%d',date)) AS month
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` ,
UNNEST (hits) hits,
UNNEST (hits.product) AS product
WHERE (_table_suffix BETWEEN '0601' AND'0731') AND
      (productRevenue IS NULL) AND
      (totals.transactions IS NULL)
)
-- join 2 tables by visitor id to pull out expected result
SELECT purchaser.month,
      SUM(purchaser.pageviews)/COUNT(DISTINCT purchaser.fullVisitorId) AS avg_pageviews_purchase,
      SUM(non_purchaser.pageviews)/COUNT(DISTINCT non_purchaser.fullVisitorId) AS avg_pageviews_non_purchase
FROM purchaser
LEFT JOIN non_purchaser USING(month)
GROUP BY month
ORDER BY purchaser.month;

-- Query 05: Average number of transactions per user that made a purchase in July 2017

-- create a CTE to get all the visitors id, total transaction
WITH purchaser AS (
  SELECT 
     totals.transactions,
     fullVisitorId,
     FORMAT_DATE('%Y%m',parse_date('%Y%m%d',date)) AS month
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
UNNEST (hits) hits,
UNNEST (hits.product) AS product
WHERE  
      (productRevenue IS NOT NULL) AND
      (totals.transactions>=1)
)
SELECT purchaser.month,
      SUM(transactions)/count(DISTINCT fullVisitorId) AS Avg_total_transactions_per_user
FROM purchaser
GROUP BY month;

-- Query 06: Average amount of money spent per session. Only include purchaser data in July 2017

WITH purchaser AS (
  SELECT    productRevenue/1000000 AS revenue,
            totals.visits,
            FORMAT_DATE('%Y%m',parse_date('%Y%m%d',date)) AS month
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
UNNEST (hits) hits,
UNNEST (hits.product) AS product
WHERE productRevenue IS NOT NULL 
      AND totals.transactions IS NOT NULL
)
SELECT month,
      SUM(revenue)/SUM(visits) AS avg_revenue_by_user_per_visit
FROM purchaser
GROUP BY month;

-- Query 07: Other products purchased by customers who purchased product "YouTube Men's Vintage Henley" in July 2017. Output should show product name and the quantity was ordered.

-- step 1. create CTE to pull out all customer id who bought product "YouTube Men% Vintage Henley" in July
WITH key_customer AS (
  SELECT  DISTINCT fullVisitorId AS customer_id,
          product.v2ProductName AS product_name,       
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST (hits) hits,
  UNNEST (hits.product) AS product
  WHERE product.productRevenue IS NOT NULL 
        AND v2ProductName LIKE 'YouTube Men% Vintage Henley'
),
-- step 2: create CTE of all customer id who bought procduct in July, except product "YouTube Men% Vintage Henley"
customer_buy_other AS ( 
SELECT fullVisitorId AS customer_id,
        product.v2ProductName AS other_purchased_products,
        sum(product.productQuantity) AS quantity
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
UNNEST (hits) hits,
UNNEST (hits.product) AS product
WHERE product.productRevenue IS NOT NULL
      AND v2ProductName NOT LIKE 'YouTube Men% Vintage Henley'
GROUP BY customer_id,product.v2ProductName
)
-- Join 2 CTEs to find out who bought product "YouTube Men% Vintage Henley" and also boght other products
SELECT other_purchased_products,
       SUM(customer_buy_other.quantity) AS quantity     
FROM key_customer
LEFT JOIN customer_buy_other USING(customer_id)
GROUP BY other_purchased_products
ORDER BY SUM(customer_buy_other.quantity) DESC ;

-- "Query 08: Calculate cohort map from product view to addtocart to purchase in Jan, Feb and March 2017. For example, 100% product view then 40% add_to_cart and 10% purchase.
-- Add_to_cart_rate = number product  add to cart/number product view. Purchase_rate = number product purchase/number product view. The output should be calculated in product level."

-- create CTE to count the number of product_view in Jan, Feb and Mar
WITH product_view AS (
      SELECT  
            COUNT(product.v2ProductName) AS num_product_view,
            FORMAT_DATE('%Y%m',parse_date('%Y%m%d',date)) AS month
      FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
      UNNEST (hits) hits,
      UNNEST (hits.product) AS product
      WHERE (_table_suffix BETWEEN '0101' AND '0331')
            AND (ecommerceaction.action_type = '2')
      GROUP BY month ),
-- create CTE to count the number of add-to-card in Jan, Feb and Mar
addtocard AS(
      SELECT  
            COUNT(product.v2ProductName) AS num_addtocart,
            FORMAT_DATE('%Y%m',parse_date('%Y%m%d',date)) AS month
      FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
      UNNEST (hits) hits,
      UNNEST (hits.product) AS product
      WHERE (_table_suffix BETWEEN '0101' AND '0331')
            AND (ecommerceaction.action_type = '3')
      GROUP BY month ),
-- create CTE to count the number of purchase in Jan, Feb and Mar
purchase AS(
      SELECT  
            COUNT(product.v2ProductName) AS num_purchase,
            FORMAT_DATE('%Y%m',parse_date('%Y%m%d',date)) AS month
      FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
      UNNEST (hits) hits,
      UNNEST (hits.product) AS product
      WHERE (_table_suffix BETWEEN '0101' AND '0331')
            AND (ecommerceaction.action_type = '6')
            AND product.productRevenue IS NOT NULL
      GROUP BY month )
-- Combine 3 CTEs above to caculate expected result
SELECT product_view.month AS month,
       num_product_view,
       addtocard.num_addtocart,
       purchase.num_purchase,
       ROUND(addtocard.num_addtocart/num_product_view*100,2) AS add_to_card_rate,
       ROUND(purchase.num_purchase/num_product_view*100,2) AS purchase_rate
FROM product_view
LEFT JOIN addtocard USING(month)
LEFT JOIN purchase USING(month)
ORDER BY  month;

