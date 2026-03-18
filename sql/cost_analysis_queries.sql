-- Cortex Code Cost Analysis Queries
-- GitHub: https://github.com/YOUR_USERNAME/cortex-code-cost-guide
-- Updated: March 2026 (verified with Snowflake Support)
--
-- ============================================
-- VIEW LATENCY & COVERAGE CHEAT SHEET
-- ============================================
-- ┌─────────────────────────────────────┬───────────┬────────────────────────────────────────────┐
-- │ View                                │ Latency   │ What it Captures                           │
-- ├─────────────────────────────────────┼───────────┼────────────────────────────────────────────┤
-- │ WAREHOUSE_METERING_HISTORY          │ ~3 hrs    │ Warehouse compute ONLY                     │
-- │ METERING_DAILY_HISTORY              │ ~3 hrs    │ Warehouse + cloud svc + copy (NOT AI)      │
-- │ CORTEX_AISQL_USAGE_HISTORY          │ ~3 hrs    │ Cortex AI token-level detail ONLY           │
-- │ CORTEX_FUNCTIONS_USAGE_HISTORY      │ ~3 hrs    │ Cortex LLM functions token detail ONLY     │
-- │ CORTEX_AGENT_USAGE_HISTORY          │ ~3 hrs    │ Cortex Agent token detail ONLY             │
-- │ USAGE_IN_CURRENCY_DAILY             │ ≤72 hrs   │ EVERYTHING in USD (compute+AI+serverless)  │
-- │ REMAINING_BALANCE_DAILY             │ ≤72 hrs   │ End-of-day balance snapshot                │
-- └─────────────────────────────────────┴───────────┴────────────────────────────────────────────┘
--
-- KEY TAKEAWAY:
--   ACCOUNT_USAGE views (Sections 2-5, 10-11) = fast (~3hr) but partial (no AI in metering)
--   ORGANIZATION_USAGE views (Sections 0-1, 6-7, 15) = complete but 1-3 day lag
--   If last 2-3 days show $0 in ORGANIZATION_USAGE queries, that's NORMAL latency.
--   Cross-check with ACCOUNT_USAGE views for near-real-time warehouse/AI data.
--

-- ============================================
-- 0. DAILY CREDIT CONSUMPTION (Recommended by Support)
-- ============================================
SELECT USAGE_DATE, USAGE_TYPE, CURRENCY, USAGE, USAGE_IN_CURRENCY
FROM SNOWFLAKE.ORGANIZATION_USAGE.USAGE_IN_CURRENCY_DAILY
WHERE USAGE_DATE >= '2026-02-23'
ORDER BY USAGE_DATE DESC;

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

-- ============================================
-- 10. DISABLE TRUST CENTER SCANNERS (Recommended by Support)
-- Saves serverless credits running silently in background
-- ============================================
SELECT * FROM SNOWFLAKE.TRUST_CENTER.SCANNER_PACKAGES;
CALL SYSTEM$TRUST_CENTER_DISABLE_SCANNER_PACKAGE('CIS Benchmarks');
CALL SYSTEM$TRUST_CENTER_DISABLE_SCANNER_PACKAGE('Threat Intelligence');

-- ============================================
-- 11. CHECK FOR AUTO-CLUSTERING (silent credit consumer)
-- ============================================
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, CLUSTERING_KEY, AUTO_CLUSTERING_ON
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES
WHERE AUTO_CLUSTERING_ON = 'YES';

-- ============================================
-- 12. DAILY RESOURCE MONITOR (Recommended by Support)
-- ============================================
CREATE OR REPLACE RESOURCE MONITOR daily_credit_monitor
  WITH
    CREDIT_QUOTA = 5
    FREQUENCY = DAILY
    START_TIMESTAMP = IMMEDIATELY
    NOTIFY_USERS = (<YOUR_USERNAME>)
    TRIGGERS
      ON 50 PERCENT DO NOTIFY
      ON 75 PERCENT DO NOTIFY
      ON 100 PERCENT DO NOTIFY;

ALTER ACCOUNT SET RESOURCE_MONITOR = daily_credit_monitor;

-- ============================================
-- 13. FIND ALL WAREHOUSES AND CHECK SETTINGS
-- ============================================
SHOW WAREHOUSES;

-- ============================================
-- 14. SET AUTO-SUSPEND FOR ALL WAREHOUSES
-- Update with your warehouse names from query 13
-- ============================================
ALTER WAREHOUSE COMPUTE_WH SET AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;

-- ============================================
-- 15. TOTAL EXPENDITURE SINCE BEGINNING (by usage type)
-- View: USAGE_IN_CURRENCY_DAILY | Latency: ≤72 hrs | Covers: ALL charges in USD
-- ============================================
SELECT
    USAGE_TYPE,
    ROUND(SUM(USAGE), 2) AS TOTAL_CREDITS,
    ROUND(SUM(USAGE_IN_CURRENCY), 2) AS TOTAL_USD,
    CURRENCY
FROM SNOWFLAKE.ORGANIZATION_USAGE.USAGE_IN_CURRENCY_DAILY
GROUP BY USAGE_TYPE, CURRENCY
ORDER BY TOTAL_USD DESC;

-- ============================================
-- 16. DAILY SPEND AGGREGATED (last 30 days)
-- View: USAGE_IN_CURRENCY_DAILY | Latency: ≤72 hrs | Covers: ALL charges in USD
-- ============================================
SELECT
    USAGE_DATE,
    ROUND(SUM(USAGE), 4) AS DAILY_CREDITS,
    ROUND(SUM(USAGE_IN_CURRENCY), 2) AS DAILY_USD,
    CURRENCY
FROM SNOWFLAKE.ORGANIZATION_USAGE.USAGE_IN_CURRENCY_DAILY
WHERE USAGE_DATE >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY USAGE_DATE, CURRENCY
ORDER BY USAGE_DATE DESC;
