-- ============================================================
-- SNOWFLAKE COST CONTROL & MONITORING QUERIES
-- Generic guide — not Cortex Code specific
-- ============================================================

-- ============================================================
-- SECTION 1: ONE-TIME SETUP (Run First)
-- ============================================================

-- 1A. Set warehouse auto-suspend to 60 seconds (minimum recommended)
ALTER WAREHOUSE COMPUTE_WH SET AUTO_SUSPEND = 60;
ALTER WAREHOUSE COMPUTE_WH SET AUTO_RESUME = TRUE;
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'XSMALL';

-- 1B. Set query timeout to 30 minutes (auto-kill long queries)
ALTER WAREHOUSE COMPUTE_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 1800;

-- 1C. Set queue timeout to 5 minutes
ALTER WAREHOUSE COMPUTE_WH SET STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 300;

-- 1D. Create resource monitor
CREATE OR REPLACE RESOURCE MONITOR trial_cost_guard
  WITH CREDIT_QUOTA = 30
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 50 PERCENT DO NOTIFY
    ON 75 PERCENT DO NOTIFY
    ON 90 PERCENT DO SUSPEND
    ON 100 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE COMPUTE_WH SET RESOURCE_MONITOR = trial_cost_guard;


-- ============================================================
-- SECTION 2: CREDIT MONITORING
-- ============================================================

-- 2A. Remaining trial balance (USD)
SELECT
    date,
    free_usage_balance AS balance_usd,
    ROUND(LAG(free_usage_balance) OVER (ORDER BY date) - free_usage_balance, 2) AS daily_spend_usd
FROM SNOWFLAKE.ORGANIZATION_USAGE.REMAINING_BALANCE_DAILY
ORDER BY date DESC
LIMIT 30;

-- 2B. Daily credit usage by service type (last 30 days)
SELECT
    SERVICE_TYPE,
    USAGE_DATE,
    CREDITS_USED,
    CREDITS_BILLED
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE USAGE_DATE >= CURRENT_DATE - 30
  AND CREDITS_USED > 0
ORDER BY USAGE_DATE DESC, CREDITS_USED DESC;

-- 2C. Credit usage by warehouse (last 30 days)
SELECT
    warehouse_name,
    ROUND(SUM(credits_used), 2) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_credits DESC;

-- 2D. Top credit-consuming users
SELECT
    user_name,
    warehouse_name,
    COUNT(*) AS query_count,
    ROUND(SUM(total_elapsed_time) / 60000, 2) AS total_minutes
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND warehouse_name IS NOT NULL
GROUP BY user_name, warehouse_name
ORDER BY total_minutes DESC
LIMIT 20;

-- 2E. Serverless credit usage breakdown
SELECT
    SERVICE_TYPE,
    ROUND(SUM(CREDITS_USED), 4) AS TOTAL_CREDITS
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE USAGE_DATE >= CURRENT_DATE - 30
GROUP BY SERVICE_TYPE
ORDER BY TOTAL_CREDITS DESC;


-- ============================================================
-- SECTION 3: FIND LONG-RUNNING QUERIES
-- ============================================================

-- 3A. Top 20 longest queries (last 24 hours)
SELECT
    query_id,
    LEFT(query_text, 200) AS query_preview,
    user_name,
    warehouse_name,
    warehouse_size,
    ROUND(total_elapsed_time / 1000, 2) AS elapsed_seconds,
    ROUND(total_elapsed_time / 60000, 2) AS elapsed_minutes,
    partitions_scanned,
    partitions_total,
    execution_status
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
  AND total_elapsed_time > 0
  AND error_code IS NULL
ORDER BY total_elapsed_time DESC
LIMIT 20;

-- 3B. Repeated expensive queries (last 7 days)
SELECT
    query_hash,
    COUNT(*) AS execution_count,
    ROUND(SUM(total_elapsed_time) / 1000, 2) AS total_seconds,
    ROUND(AVG(total_elapsed_time) / 1000, 2) AS avg_seconds,
    ANY_VALUE(LEFT(query_text, 200)) AS sample_query
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND total_elapsed_time > 0
  AND warehouse_name IS NOT NULL
GROUP BY query_hash
ORDER BY total_seconds DESC
LIMIT 20;

-- 3C. Queries spilling to disk (need optimization)
SELECT
    query_id,
    LEFT(query_text, 200) AS query_preview,
    warehouse_size,
    ROUND(total_elapsed_time / 1000, 2) AS elapsed_seconds,
    bytes_spilled_to_local_storage,
    bytes_spilled_to_remote_storage
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
ORDER BY bytes_spilled_to_remote_storage DESC
LIMIT 20;

-- 3D. Queued queries (warehouse overloaded)
SELECT
    query_id,
    LEFT(query_text, 200) AS query_preview,
    warehouse_name,
    ROUND(queued_overload_time / 1000, 2) AS queued_seconds,
    ROUND(total_elapsed_time / 1000, 2) AS total_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND queued_overload_time > 0
ORDER BY queued_overload_time DESC
LIMIT 20;


-- ============================================================
-- SECTION 4: QUERY OPTIMIZATION
-- ============================================================

-- 4A. Preview query plan BEFORE execution (use EXPLAIN)
-- EXPLAIN SELECT col1, col2 FROM my_table WHERE date_col >= '2026-01-01';

-- 4B. Check partition pruning efficiency for a specific query
-- Replace <query_id> with actual query ID
-- SELECT
--     query_id,
--     partitions_scanned,
--     partitions_total,
--     ROUND(partitions_scanned / NULLIF(partitions_total, 0) * 100, 2) AS pct_scanned
-- FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
-- WHERE query_id = '<your_query_id>';


-- ============================================================
-- SECTION 5: EMERGENCY ACTIONS
-- ============================================================

-- 5A. Suspend warehouse immediately (stop credit burn)
-- ALTER WAREHOUSE COMPUTE_WH SUSPEND;

-- 5B. Cancel all queries on a warehouse
-- SELECT SYSTEM$CANCEL_ALL_QUERIES(SYSTEM$GET_CURRENT_SESSION_ID());

-- 5C. Check resource monitors
SHOW RESOURCE MONITORS;

-- 5D. Check warehouse state
SHOW WAREHOUSES;


-- ============================================================
-- SECTION 6: SILENT CREDIT CONSUMERS CHECK
-- ============================================================

-- 6A. Trust Center scanners (serverless credits)
SELECT * FROM SNOWFLAKE.TRUST_CENTER.SCANNER_PACKAGES;

-- 6B. Auto-clustering on tables
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, AUTO_CLUSTERING_ON
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES
WHERE AUTO_CLUSTERING_ON = 'YES';

-- 6C. Scheduled Tasks consuming credits (last 7 days)
SELECT NAME, STATE, SCHEDULE
FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
WHERE SCHEDULED_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND STATE = 'SUCCEEDED'
GROUP BY NAME, STATE, SCHEDULE
ORDER BY NAME;
