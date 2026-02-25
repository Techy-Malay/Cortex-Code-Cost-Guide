# Cortex Code Cost Analysis: What They Don't Tell You

> **TL;DR:** I lost 50% of my Snowflake credits ($112 USD) in just 3 days using Cortex Code. Here's what I learned.

## The Surprise

| Metric | Value |
|--------|-------|
| Starting Balance | $312.92 |
| Balance After 3 Days | $201.43 |
| **Total Lost** | **$111.49 (36%)** |
| Peak Single Day Cost | $79.89 (Feb 23) |

## Cost Breakdown (Feb 22-24, 2026)

| Date | Credits | USD Cost |
|------|---------|----------|
| Feb 22 | 1.05 | $0.64 |
| Feb 23 | 18.76 | $79.89 |
| Feb 24 | 5.94 | $31.48 |
| **Total** | **25.75** | **$112.01** |

## Key Discovery: It's NOT Free

Many users assume Cortex Code is free during preview. **It's not.**

The billing is based on:
- **Input tokens** (your prompts)
- **Output tokens** (AI responses)
- Effective rate: ~$4.25 per credit

## SQL Queries to Check Your Costs

### 1. Daily Balance Changes (USD)
```sql
SELECT 
    date,
    free_usage_balance,
    LAG(free_usage_balance) OVER (ORDER BY date) AS prev_balance,
    ROUND(LAG(free_usage_balance) OVER (ORDER BY date) - free_usage_balance, 2) AS daily_spend_usd
FROM SNOWFLAKE.ORGANIZATION_USAGE.REMAINING_BALANCE_DAILY
ORDER BY date DESC
LIMIT 30;
```

### 2. Cortex Agent Usage by Day
```sql
SELECT 
    DATE(start_time) AS usage_date,
    user_name,
    ROUND(SUM(token_credits), 4) AS total_credits,
    SUM(tokens) AS total_tokens,
    COUNT(*) AS request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
GROUP BY DATE(start_time), user_name
ORDER BY usage_date DESC;
```

### 3. Hourly Pattern Analysis
```sql
SELECT 
    DATE_TRUNC('hour', start_time) AS hour,
    ROUND(SUM(token_credits), 4) AS credits,
    SUM(tokens) AS tokens,
    COUNT(*) AS requests
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE DATE(start_time) = CURRENT_DATE()
GROUP BY DATE_TRUNC('hour', start_time)
ORDER BY hour;
```

### 4. Service Type Breakdown
```sql
SELECT 
    service_type,
    ROUND(SUM(credits_used), 2) AS total_credits,
    ROUND(SUM(credits_used) / SUM(SUM(credits_used)) OVER () * 100, 1) AS pct
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
WHERE start_time >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY service_type
ORDER BY total_credits DESC;
```

## Cost Optimization Tips

| Tip | Impact |
|-----|--------|
| Keep prompts short | Fewer input tokens |
| Say "just SQL" or "brief" | Fewer output tokens |
| Batch related questions | Less overhead |
| Analyze results yourself | Skip AI analysis cost |
| Ask for file write in original request | Avoid follow-up messages |

## Important Notes

- ACCOUNT_USAGE views have **45 min - 2 hour latency**
- Balance updates daily in `REMAINING_BALANCE_DAILY`
- Writing to file = same cost as chat response (not doubled)
- Each new message = new token charges

## Screenshots to Include

1. Cost Management page showing balance drop
2. Query results showing CORTEX_AGENT_USAGE_HISTORY
3. Daily spend chart

## How to Restrict Cortex Code Usage

### Block Access by Role
```sql
-- Revoke Cortex access from a role
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE analyst_role;

-- Grant Cortex access to specific role only
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE power_user_role;
```

### Role-Based Restriction Pattern
```sql
-- Create limited role WITHOUT Cortex access
CREATE ROLE limited_analyst;
GRANT USAGE ON DATABASE my_db TO ROLE limited_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA my_db.my_schema TO ROLE limited_analyst;
-- DO NOT grant SNOWFLAKE.CORTEX_USER

-- Create power role WITH Cortex access
CREATE ROLE power_analyst;
GRANT ROLE limited_analyst TO ROLE power_analyst;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE power_analyst;
```

### Disable Cross-Region Models (Account Level)
```sql
-- Run as ACCOUNTADMIN
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'NONE';
```

## Documentation vs Reality Discrepancy

**Official Snowflake Documentation states:**
> "Cortex Code in Snowsight is currently free of charge to use."
> Source: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code

**However**, my account shows charges in `CORTEX_AGENT_USAGE_HISTORY` for Snowsight usage (claude-opus-4-5 model).

See `SNOWFLAKE_SUPPORT_TICKET.md` for details to report this discrepancy.

## License

MIT - Share freely to help others understand Cortex Code costs.
