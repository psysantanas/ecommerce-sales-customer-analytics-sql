WITH monthly_sales AS (
    SELECT 
        DATE_TRUNC('month', order_date)::DATE AS order_month,
        SUM(amount) AS total_revenue,
        COUNT(DISTINCT user_id) AS active_users,
        ROUND(AVG(amount), 2) AS aov
    FROM orders
    WHERE status = 'delivered'
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT 
    order_month,
    total_revenue,
    active_users,
    aov,
    LAG(total_revenue) OVER (ORDER BY order_month) AS prev_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY order_month)) * 100.0 
        / LAG(total_revenue) OVER (ORDER BY order_month), 
        1
    ) AS mom_growth_pct
FROM monthly_sales
ORDER BY order_month;

WITH user_orders AS (
    SELECT
        user_id,
        order_date,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY order_date
        ) AS rn,
        LEAD(order_date::DATE) OVER (
            PARTITION BY user_id
            ORDER BY order_date
        ) - order_date::DATE AS days_to_next_order
    FROM orders
    WHERE status = 'delivered'
)
SELECT
    ROUND(AVG(days_to_next_order), 1) AS avg_days_to_second_order,
    COUNT(DISTINCT user_id) AS users_with_repeat_orders
FROM user_orders
WHERE rn = 1
  AND days_to_next_order IS NOT NULL;

WITH category_sales AS (
    SELECT
        c.category_name,
        ROUND(SUM(oi.quantity * oi.unit_price)) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    JOIN categories c ON p.category_id = c.category_id
    WHERE o.status = 'delivered'
    GROUP BY c.category_name
)
SELECT
    category_name,
    revenue,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (), 2) AS pct_of_total,
    DENSE_RANK() OVER (ORDER BY revenue DESC) AS category_rank
FROM category_sales
ORDER BY category_rank;