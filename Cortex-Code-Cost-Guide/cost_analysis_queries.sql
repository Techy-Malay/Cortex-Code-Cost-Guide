-- Cortex Code Cost Analysis Queries
-- GitHub: https://github.com/YOUR_USERNAME/cortex-code-cost-guide

-- ============================================
-- 1. CHECK YOUR BALANCE TREND (USD)
-- ============================================
SELECT 
    date,
    free_usage_balance AS balance_usd,
    LAG(free_usage_balance) OVER (ORDER BY date) AS prev_balance,
    ROUND(LAG(free_usage_balance) OVER (ORDER BY date) - free_usage_balance, 2) AS daily_spend_usd
FROM SNOWFLAKE.ORGANIZATION_USAGE.REMAINING_BALANCE_DAILY
ORDER BY date DESC
LIMIT 30;

-- ============================================
-- 2. CORTEX AGENT USAGE BY DAY
-- ============================================
SELECT 
    DATE(start_time) AS usage_date,
    user_name,
    ROUND(SUM(token_credits), 4) AS total_credits,
    SUM(tokens) AS total_tokens,
    COUNT(*) AS request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
GROUP BY DATE(start_time), user_name
ORDER BY usage_date DESC;

-- ============================================
-- 3. HOURLY PATTERN (FIND YOUR PEAK HOURS)
-- ============================================
SELECT 
    DATE_TRUNC('hour', start_time) AS hour,
    ROUND(SUM(token_credits), 4) AS credits,
    SUM(tokens) AS tokens,
    COUNT(*) AS requests
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE start_time >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY DATE_TRUNC('hour', start_time)
ORDER BY hour DESC;

-- ============================================
-- 4. CREDIT vs USD COMPARISON
-- ============================================
WITH daily_usd AS (
    SELECT 
        date,
        ROUND(LAG(free_usage_balance) OVER (ORDER BY date) - free_usage_balance, 2) AS usd_cost
    FROM SNOWFLAKE.ORGANIZATION_USAGE.REMAINING_BALANCE_DAILY
),
daily_credits AS (
    SELECT 
        DATE(start_time) AS date,
        ROUND(SUM(credits_used), 2) AS credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
    GROUP BY DATE(start_time)
)
SELECT 
    c.date,
    c.credits,
    u.usd_cost,
    ROUND(u.usd_cost / NULLIF(c.credits, 0), 2) AS usd_per_credit
FROM daily_credits c
LEFT JOIN daily_usd u ON c.date = u.date
WHERE c.date >= DATEADD(DAY, -30, CURRENT_DATE())
ORDER BY c.date DESC;

-- ============================================
-- 5. SERVICE TYPE BREAKDOWN
-- ============================================
SELECT 
    service_type,
    ROUND(SUM(credits_used), 2) AS total_credits,
    ROUND(SUM(credits_used) / SUM(SUM(credits_used)) OVER () * 100, 1) AS percentage
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
WHERE start_time >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY service_type
ORDER BY total_credits DESC;

-- ============================================
-- 6. TOP SPENDING DAYS (ALL TIME)
-- ============================================
SELECT 
    date,
    free_usage_balance,
    ROUND(LAG(free_usage_balance) OVER (ORDER BY date) - free_usage_balance, 2) AS daily_spend_usd
FROM SNOWFLAKE.ORGANIZATION_USAGE.REMAINING_BALANCE_DAILY
ORDER BY daily_spend_usd DESC NULLS LAST
LIMIT 10;

-- ============================================
-- 7. MONTHLY SUMMARY
-- ============================================
WITH daily_spend AS (
    SELECT 
        DATE_TRUNC('month', date) AS month,
        ROUND(LAG(free_usage_balance) OVER (ORDER BY date) - free_usage_balance, 2) AS spend
    FROM SNOWFLAKE.ORGANIZATION_USAGE.REMAINING_BALANCE_DAILY
)
SELECT 
    month,
    ROUND(SUM(spend), 2) AS monthly_spend_usd
FROM daily_spend
WHERE spend IS NOT NULL
GROUP BY month
ORDER BY month DESC;

-- ============================================
-- 8. RESTRICT CORTEX CODE ACCESS BY ROLE
-- ============================================
-- Revoke access from a role
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE analyst_role;

-- Grant access to specific role only
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE power_user_role;

-- Check who has Cortex access
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.CORTEX_USER;

-- ============================================
-- 9. DISABLE CROSS-REGION MODELS (ACCOUNTADMIN)
-- ============================================
-- Limit model availability
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'NONE';
