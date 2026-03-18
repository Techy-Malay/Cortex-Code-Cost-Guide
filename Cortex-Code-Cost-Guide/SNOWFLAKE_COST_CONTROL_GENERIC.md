# Snowflake Cost Control Guide — Generic (For All Users)

> A comprehensive guide to controlling Snowflake costs, optimizing queries, and avoiding surprise charges — whether or not you use Cortex Code.

---

## 1. Warehouse Cost Control (Biggest Cost Driver)

### Auto-Suspend: The #1 Setting to Get Right

| Setting | Recommendation | Why |
|---------|---------------|-----|
| AUTO_SUSPEND = 60 | Minimum recommended | Snowflake bills per-second after the first 60 seconds. Setting below 60 has NO benefit because the minimum billing is 60 seconds. |
| AUTO_SUSPEND = 300 | For frequent queries (every 2-5 min) | Avoids constant suspend/resume cycles where each resume costs 60 seconds minimum. |
| AUTO_SUSPEND = 0 or NULL | NEVER (unless heavy 24/7 workload) | Warehouse runs forever = credits burn forever. |
| AUTO_RESUME = TRUE | Always | Warehouse starts automatically when a query arrives. |

```sql
-- Set optimal auto-suspend (60 seconds = 1 minute minimum)
ALTER WAREHOUSE COMPUTE_WH SET AUTO_SUSPEND = 60;
ALTER WAREHOUSE COMPUTE_WH SET AUTO_RESUME = TRUE;

-- Check current setting
SHOW WAREHOUSES LIKE 'COMPUTE_WH';
```

### Why NOT Less Than 60 Seconds?
Snowflake charges a **minimum of 60 seconds** every time a warehouse resumes. If you set AUTO_SUSPEND = 10, and queries come every 15 seconds, the warehouse suspends and resumes repeatedly — each resume = 60-second charge. You end up paying MORE.

### Warehouse Sizing

| Size | Credits/Hour | Best For |
|------|-------------|----------|
| X-Small | 1 | Development, testing, simple queries |
| Small | 2 | Light production workloads |
| Medium | 4 | Moderate production |
| Large | 8 | Complex queries, large datasets |
| X-Large+ | 16+ | Heavy production only |

**Rule**: Start with X-Small. Scale up ONLY if queries are slow. Bigger is NOT always faster for simple queries.

```sql
-- Keep warehouse small for learning/development
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'XSMALL';
```

---

## 2. Resource Monitors (Set Spending Limits)

Resource monitors alert you and/or suspend warehouses when credit usage hits a threshold.

```sql
-- Create a resource monitor: alerts at 50%, 75%, suspends at 90%, force-suspends at 100%
CREATE OR REPLACE RESOURCE MONITOR cost_guard
  WITH CREDIT_QUOTA = 50
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 50 PERCENT DO NOTIFY
    ON 75 PERCENT DO NOTIFY
    ON 90 PERCENT DO SUSPEND
    ON 100 PERCENT DO SUSPEND_IMMEDIATE;

-- Assign to warehouse
ALTER WAREHOUSE COMPUTE_WH SET RESOURCE_MONITOR = cost_guard;

-- Assign to entire account (only one account monitor allowed)
ALTER ACCOUNT SET RESOURCE_MONITOR = cost_guard;

-- View resource monitors
SHOW RESOURCE MONITORS;
```

**Important**: Resource monitors only track **warehouse** credits. They do NOT track serverless features (Snowpipe, Tasks, Cortex AI, Trust Center scanners). Use **Budgets** for those.

---

## 3. Disable Trust Center Scanners (Silent Credit Consumers)

Snowflake's Trust Center runs background scanners that consume **serverless credits silently**. For trial/learning accounts, disable non-essential ones (recommended by Snowflake Support):

| Scanner | Can Disable? | Recommendation |
|---------|-------------|----------------|
| Security Essentials | No (always on) | Minimal cost, keep it |
| CIS Benchmarks | Yes | **Disable** — saves credits |
| Threat Intelligence | Yes | **Disable** — saves credits |

```sql
-- Check current scanner status
SELECT * FROM SNOWFLAKE.TRUST_CENTER.SCANNER_PACKAGES;

-- Disable non-essential scanners
CALL SYSTEM$TRUST_CENTER_DISABLE_SCANNER_PACKAGE('CIS Benchmarks');
CALL SYSTEM$TRUST_CENTER_DISABLE_SCANNER_PACKAGE('Threat Intelligence');

-- Verify
SELECT * FROM SNOWFLAKE.TRUST_CENTER.SCANNER_PACKAGES;
```

---

## 4. Budgets (Track ALL Spending Including Serverless)

Budgets track everything: warehouses, serverless tasks, AI services, Snowpipe, etc.

**Why budgets over resource monitors?** Resource monitors only guard warehouse compute. Budgets guard *all* spending (AI, serverless, storage, compute).

### Activate Account Budget (SQL)

```sql
USE ROLE ACCOUNTADMIN;

-- Step 1: Activate the built-in account budget
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ACTIVATE();

-- Step 2: Set monthly spending limit (adjust to your comfort level)
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_SPENDING_LIMIT(50);

-- Step 3: Set up email notifications
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_EMAIL_NOTIFICATIONS(
  'SNOWFLAKE.NOTIFICATION.ACCOUNT_BUDGET_SNOWFLAKE_NOTIFICATION_INTEGRATION',
  ARRAY_CONSTRUCT('your-email@example.com')
);

-- Step 4: Verify
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_SPENDING_LIMIT();
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_SPENDING_HISTORY();
```

### Account Budget Notes

| Detail | Value |
|--------|-------|
| Latency | ~24 hours for spending data |
| Scope | ALL account spending automatically |
| Tag/resource tracking | NOT supported (use custom budgets for that) |
| Best used with | Resource monitors as secondary warehouse-specific guard |

---

## 5. Find and Fix Long-Running Queries

### Find Long-Running Queries (Last 24 Hours)

```sql
-- Top 20 longest-running queries in last 24 hours
SELECT
    query_id,
    query_text,
    user_name,
    warehouse_name,
    warehouse_size,
    ROUND(total_elapsed_time / 1000, 2) AS elapsed_seconds,
    ROUND(total_elapsed_time / 60000, 2) AS elapsed_minutes,
    partitions_scanned,
    partitions_total,
    bytes_scanned,
    rows_produced,
    execution_status
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
  AND total_elapsed_time > 0
  AND error_code IS NULL
ORDER BY total_elapsed_time DESC
LIMIT 20;
```

### Find Repeated Expensive Queries (Last 7 Days)

```sql
-- Queries that run frequently and consume the most total time
SELECT
    query_hash,
    COUNT(*) AS execution_count,
    ROUND(SUM(total_elapsed_time) / 1000, 2) AS total_seconds,
    ROUND(AVG(total_elapsed_time) / 1000, 2) AS avg_seconds,
    ANY_VALUE(query_text) AS sample_query,
    ANY_VALUE(query_id) AS sample_query_id
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND total_elapsed_time > 0
  AND warehouse_name IS NOT NULL
GROUP BY query_hash
ORDER BY total_seconds DESC
LIMIT 20;
```

### Find Queries Spilling to Disk (Performance Problem)

```sql
-- Queries spilling to local/remote storage = too much data for warehouse memory
SELECT
    query_id,
    query_text,
    warehouse_size,
    ROUND(total_elapsed_time / 1000, 2) AS elapsed_seconds,
    bytes_spilled_to_local_storage,
    bytes_spilled_to_remote_storage
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
ORDER BY bytes_spilled_to_remote_storage DESC
LIMIT 20;
```

### Find Queued Queries (Warehouse Overloaded)

```sql
-- Queries that spent time waiting in queue
SELECT
    query_id,
    query_text,
    warehouse_name,
    ROUND(queued_overload_time / 1000, 2) AS queued_seconds,
    ROUND(total_elapsed_time / 1000, 2) AS total_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND queued_overload_time > 0
ORDER BY queued_overload_time DESC
LIMIT 20;
```

---

## 6. Query Optimization Checklist (Before Execution)

Run through this checklist BEFORE executing heavy queries:

### Must-Do Before Running Any Query

- [ ] **Use LIMIT during development** — `SELECT * FROM table LIMIT 100` instead of full table scan
- [ ] **Never SELECT *** — only select columns you need
- [ ] **Add WHERE filters** — reduce data scanned
- [ ] **Check table size first** — `SELECT COUNT(*) FROM table` or `SHOW TABLES LIKE 'table_name'`
- [ ] **Use EXPLAIN** to preview query plan before execution

```sql
-- Preview query plan WITHOUT executing
EXPLAIN
SELECT col1, col2 FROM my_table WHERE date_col >= '2026-01-01';
```

### Query Writing Best Practices

| Do This | Not This | Why |
|---------|----------|-----|
| `SELECT col1, col2` | `SELECT *` | Reduces data scanned |
| `WHERE date >= '2026-01-01'` | No filter | Enables partition pruning |
| `LIMIT 100` (during dev) | Full result set | Avoids scanning entire table |
| `JOIN` with proper keys | Cartesian joins | Prevents row explosion |
| Use CTEs for readability | Nested subqueries | Easier to optimize |
| `COUNT(DISTINCT col)` carefully | Overuse of DISTINCT | DISTINCT is expensive |

### Partition Pruning

Snowflake organizes data into micro-partitions. Good filters = fewer partitions scanned = faster + cheaper.

```sql
-- Check how well your query prunes (look at partitions_scanned vs partitions_total)
SELECT
    query_id,
    partitions_scanned,
    partitions_total,
    ROUND(partitions_scanned / NULLIF(partitions_total, 0) * 100, 2) AS pct_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_id = '<your_query_id>';
```

If `pct_scanned` is close to 100%, your filter isn't helping — consider clustering the table.

---

## 7. Credit Monitoring Queries

### Daily Credit Consumption (Recommended by Support)

```sql
SELECT USAGE_DATE, USAGE_TYPE, CURRENCY, USAGE, USAGE_IN_CURRENCY
FROM SNOWFLAKE.ORGANIZATION_USAGE.USAGE_IN_CURRENCY_DAILY
WHERE USAGE_DATE >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY USAGE_DATE DESC;
```

### Daily Credit Usage by Service Type

```sql
SELECT
    SERVICE_TYPE,
    USAGE_DATE,
    CREDITS_USED,
    CREDITS_BILLED
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE USAGE_DATE >= CURRENT_DATE - 30
  AND CREDITS_USED > 0
ORDER BY USAGE_DATE DESC, CREDITS_USED DESC;
```

### Remaining Trial Balance (USD)

```sql
SELECT
    date,
    free_usage_balance AS balance_usd,
    ROUND(LAG(free_usage_balance) OVER (ORDER BY date) - free_usage_balance, 2) AS daily_spend_usd
FROM SNOWFLAKE.ORGANIZATION_USAGE.REMAINING_BALANCE_DAILY
ORDER BY date DESC
LIMIT 30;
```

### Credit Usage by Warehouse

```sql
SELECT
    warehouse_name,
    ROUND(SUM(credits_used), 2) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_credits DESC;
```

### Top Credit-Consuming Users

```sql
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
```

---

## 8. Serverless Feature Costs (Often Overlooked)

These features consume credits WITHOUT a warehouse and are NOT controlled by resource monitors:

| Feature | How It Charges | Control |
|---------|---------------|---------|
| Snowpipe | Per file loaded | Limit file frequency |
| Tasks (serverless) | Per execution | Use CRON schedules wisely |
| Auto-Clustering | Per re-cluster operation | Only cluster large, frequently-queried tables |
| Materialized Views | Per refresh | Use only when needed |
| Search Optimization | Per maintenance | Apply selectively |
| Cortex AI Functions | Per token | Keep prompts concise |
| Snowpark Container Services | Per compute pool uptime | Suspend pools when not in use |
| Trust Center scanners | Per scan execution | Disable CIS Benchmarks & Threat Intelligence |

```sql
-- Check serverless credit usage
SELECT
    SERVICE_TYPE,
    ROUND(SUM(CREDITS_USED), 4) AS TOTAL_CREDITS
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE USAGE_DATE >= CURRENT_DATE - 30
GROUP BY SERVICE_TYPE
ORDER BY TOTAL_CREDITS DESC;
```

---

## 9. Check for Auto-Clustering (Silent Credit Consumer)

```sql
-- Find tables with auto-clustering enabled
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, CLUSTERING_KEY, AUTO_CLUSTERING_ON
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES
WHERE AUTO_CLUSTERING_ON = 'YES';

-- Disable auto-clustering on a table if not needed
-- ALTER TABLE <db>.<schema>.<table> SUSPEND RECLUSTER;
```

---

## 10. Quick Setup Script (Run This First)

```sql
-- ============================================================
-- RUN THIS ONCE TO SET UP COST CONTROLS
-- ============================================================

-- 1. Optimize warehouse settings
ALTER WAREHOUSE COMPUTE_WH SET
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  WAREHOUSE_SIZE = 'XSMALL';

-- 2. Create resource monitor
CREATE OR REPLACE RESOURCE MONITOR trial_cost_guard
  WITH CREDIT_QUOTA = 30
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 50 PERCENT DO NOTIFY
    ON 75 PERCENT DO NOTIFY
    ON 90 PERCENT DO SUSPEND
    ON 100 PERCENT DO SUSPEND_IMMEDIATE;

-- 3. Assign to warehouse
ALTER WAREHOUSE COMPUTE_WH SET RESOURCE_MONITOR = trial_cost_guard;

-- 4. Set statement timeout (kill queries running longer than 30 minutes)
ALTER WAREHOUSE COMPUTE_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 1800;

-- 5. Set statement queue timeout (don't queue queries longer than 5 minutes)
ALTER WAREHOUSE COMPUTE_WH SET STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 300;

-- 6. Disable Trust Center scanners (recommended by Snowflake Support)
CALL SYSTEM$TRUST_CENTER_DISABLE_SCANNER_PACKAGE('CIS Benchmarks');
CALL SYSTEM$TRUST_CENTER_DISABLE_SCANNER_PACKAGE('Threat Intelligence');
```

---

## 11. Cost Control Cheat Sheet

| Action | Command | Impact |
|--------|---------|--------|
| Suspend warehouse | `ALTER WAREHOUSE wh SUSPEND` | Stops credit burn immediately |
| Resume warehouse | `ALTER WAREHOUSE wh RESUME` | 60-second minimum charge |
| Check warehouse state | `SHOW WAREHOUSES` | See if running/suspended |
| Kill a running query | `SELECT SYSTEM$CANCEL_ALL_QUERIES(session_id)` | Stops runaway queries |
| Set query timeout | `ALTER WAREHOUSE wh SET STATEMENT_TIMEOUT_IN_SECONDS = 1800` | Auto-kills long queries |
| Check remaining balance | Query `REMAINING_BALANCE_DAILY` | Track spending trend |

---

> **Author**: Malaya — Student exploring Snowflake for career development
>
> **Disclaimer**: Based on Snowflake documentation and best practices as of March 2026. Always verify with official docs.
