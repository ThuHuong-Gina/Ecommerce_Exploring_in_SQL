# Ecommerce Exploring in SQL
In this project, I will explore the sale data of a E-commerce company in Google BigQuery
## I. INTRODUCTION
In this SQL project, I will use the e-commerce dataset from Google BigQuery. The dataset contains obfuscated Google Analytics 360 data from the Google Merchandise Store, a real ecommerce store, in 2017. The Google Merchandise Store sells Google branded merchandise. It includes the following kinds of information:

- *Traffic source data*: information about where website visitors originate. This includes data about organic traffic, paid search traffic, display traffic, etc.
- *Content data*: information about the behavior of users on the site. This includes the URLs of pages that visitors look at, how they interact with content, etc.
- *Transactional data*: information about the transactions that occur on the Google Merchandise Store website.

## II. HOW TO ACCESS THE DATASET
The eCommerce dataset is stored in a public Google BigQuery dataset. To access the dataset, follow these steps:

- Log in to your Google Cloud Platform account and create a new project.
- Navigate to the BigQuery console and select your newly created project.
- In the navigation panel, select "Add Data" and then "Search a project".
- Enter the project ID "bigquery-public-data.google_analytics_sample.ga_sessions" and click "Enter".
- Click on the "ga_sessions_" table to open it.

## III. E-commerce dataset Schema
Check the data set schema [here](https://support.google.com/analytics/answer/3437719?hl=en&ref_topic=3416089&sjid=4658389318173884680-AP) 

## IV. TARGET
- Overview of the activities of the company in a period of time
- Bounce rate per traffic source
- Revenue by traffic source
- Number of transactions, pageviews, and money spend per session
- The company's products
  
## V. DATASET EXPLORATION
In this project, I will explore this dataset through 8 queries in [BigQuery](https://console.cloud.google.com/bigquery?sq=913501308233:b57273029d394e9abe3eaefa5bf7af38)

### Query 1. Calculate total visit, pageview, transaction for Jan, Feb and March 2017 (order by month)

```
SELECT  
      FORMAT_DATE('%Y%m',parse_date('%Y%m%d',date)) AS month, 
      SUM(totals.visits) AS visits,
      SUM(totals.pageviews) AS pagaviews,
      SUM(totals.transactions) AS transactions
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
where _table_suffix BETWEEN '0101' AND'0331'
GROUP BY month
ORDER BY month;
```
=> Result: 

![image](https://github.com/ThuHuong-Gina/Ecommerce_Exploring_in_SQL/assets/141025228/f018a2cf-f91e-42ff-b711-3b53fc5a1d4b)

### Query 2: Bounce rate per traffic source in July 2017 (Bounce_rate = num_bounce/total_visit) (order by total_visit DESC)
```
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
```
=> Results (top 10 rows):

![image](https://github.com/ThuHuong-Gina/Ecommerce_Exploring_in_SQL/assets/141025228/3cba1ec7-4d72-4a27-8579-bc5a0cab5dd2)

### Query 3: Revenue by traffic source by week, by month in June 2017

```
-- Get data by week
(SELECT  'Week' as time_type,
        FORMAT_DATE('%Y-w%W',parse_date('%Y%m%d',date)) AS time_June,
        trafficSource.source,
        ROUND(SUM(productRevenue)/1000000,2) AS revenue_miliion
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
        ROUND(SUM(productRevenue)/1000000,2) AS revenue_miliion
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*` ,
UNNEST (hits) hits,
UNNEST (hits.product) AS product
GROUP BY trafficSource.source,time_June)
ORDER BY revenue_miliion DESC;
```
=> Results (top 10 rows):

![image](https://github.com/ThuHuong-Gina/Ecommerce_Exploring_in_SQL/assets/141025228/296331a4-afe1-4f90-b6b8-83d952d5800d)

### Query 04: Average number of pageviews by purchaser type (purchasers vs non-purchasers) in June, July 2017.
```
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
```
=> Result:


### Query 05: Average number of transactions per user that made a purchase in July 2017
```
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
```
=> Result:

![image](https://github.com/ThuHuong-Gina/Ecommerce_Exploring_in_SQL/assets/141025228/ba101ce0-32c8-4878-9396-bad3dc488b24)

### Query 06: Average amount of money spent per session. Only include purchaser data in July 2017
```
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
```
=> Result:

![image](https://github.com/ThuHuong-Gina/Ecommerce_Exploring_in_SQL/assets/141025228/1a88d1b6-f880-42a5-961d-bb50c036f34a)

### Query 07: Other products purchased by customers who purchased product "YouTube Men's Vintage Henley" in July 2017. Output should show product name and the quantity was ordered.
```
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
```
=> Result (Top 10 rows): 

![image](https://github.com/ThuHuong-Gina/Ecommerce_Exploring_in_SQL/assets/141025228/49d29919-3b3b-4241-a824-af670fd38047)

### Query 08: Calculate cohort map from product view to addtocart to purchase in Jan, Feb and March 2017. For example, 100% product view then 40% add_to_cart and 10% purchase.
Add_to_cart_rate = number product  add to cart/number product view. Purchase_rate = number product purchase/number product view. The output should be calculated in product level."
```
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
```
=> Result: 

![image](https://github.com/ThuHuong-Gina/Ecommerce_Exploring_in_SQL/assets/141025228/a3ce60cf-7be3-419e-b85e-39911ee47ecf)

## VI. CONCLUSION

In summary, my analysis of the eCommerce dataset using SQL within Google BigQuery, leveraging the Google Analytics dataset, has unveiled numerous intriguing findings.

- By delving into the eCommerce dataset, I have acquired valuable insights into various metrics including total visits, pageviews, transaction data, bounce rates, and revenue per traffic source. These insights have the potential to shape future business decisions.

- To delve even deeper into these insights and uncover key trends, the next phase will involve visualizing the data using tools such as Power BI or Tableau.

- Overall, this project has underscored the effectiveness of harnessing SQL and big data tools like Google BigQuery for gaining valuable insights from extensive datasets.
