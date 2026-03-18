# Snowflake Support Ticket: Cortex Code Billing Discrepancy

## Issue Summary

Documentation states Cortex Code in Snowsight is **free**, but my account shows charges.

---

## Documentation Reference

**URL:** https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code

**Exact Quote from Documentation:**
> "Cortex Code in Snowsight is currently free of charge to use. Details on pricing and billing are planned but you will be notified before any charges are applied for this feature."

**Screenshot recommended:** Take a screenshot of this section for your records.

---

## Evidence of Charges

### Query to Show Charges
```sql
SELECT 
    DATE(start_time) AS usage_date,
    user_name,
    ROUND(SUM(token_credits), 4) AS total_credits,
    SUM(tokens) AS total_tokens,
    COUNT(*) AS request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE start_time >= '2026-02-22'
GROUP BY DATE(start_time), user_name
ORDER BY usage_date DESC;
```

### My Results
| Date | User | Credits | Tokens | Requests |
|------|------|---------|--------|----------|
| Feb 24 | SFTRAINING | 5.14 | 2,284,780 | 78 |
| Feb 23 | SFTRAINING | 17.92 | 9,202,305 | 265 |
| Feb 22 | SFTRAINING | 0.92 | 245,963 | 22 |

### Balance Impact (USD)
```sql
SELECT 
    date,
    free_usage_balance,
    ROUND(LAG(free_usage_balance) OVER (ORDER BY date) - free_usage_balance, 2) AS daily_spend_usd
FROM SNOWFLAKE.ORGANIZATION_USAGE.REMAINING_BALANCE_DAILY
WHERE date BETWEEN '2026-02-22' AND '2026-02-25'
ORDER BY date;
```

| Date | Balance | Daily Spend USD |
|------|---------|-----------------|
| Feb 22 | $312.92 | $0.64 |
| Feb 23 | $233.03 | $79.89 |
| Feb 24 | $201.55 | $31.48 |
| Feb 25 | $201.43 | $0.12 |

**Total charged (3 days): ~$112 USD**

---

## Usage Details Showing Snowsight (Not CLI)

```sql
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE DATE(start_time) = '2026-02-23'
LIMIT 1;
```

**Key fields indicating Snowsight usage:**
- `AGENT_ID = 0` (built-in, not custom agent)
- `AGENT_NAME = NULL` (Cortex Code in Snowsight)
- `MODEL = claude-opus-4-5`

---

## Questions for Snowflake Support

1. **Is Cortex Code in Snowsight still free as documented?**

2. **If pricing changed, why was I not notified as the documentation promises?**

3. **Does the claude-opus-4-5 model have different billing than other models?**

4. **Can I get a refund/credit for charges during the documented "free" period?**

5. **When will documentation be updated to reflect current billing?**

---

## Account Information (for Support)

| Field | Value |
|-------|-------|
| Account Locator | UR99486 |
| Account Name | DL42731 |
| Organization | ZBQKWGB |
| Region | AWS_CA_CENTRAL_1 |
| Service Level | Business Critical |
| User | SFTRAINING |

---

## How to Contact Snowflake Support

### Option 1: Snowsight (Recommended)
1. Log in to Snowsight
2. Click **Help** icon (?) in bottom-left
3. Select **Contact Support**
4. Choose **Create a Case**

### Option 2: Support Portal
1. Go to: https://community.snowflake.com/s/support
2. Log in with your Snowflake credentials
3. Click **Create a Case**

### Option 3: Email
- Email: support@snowflake.com
- Include account locator and organization name

---

## Recommended Case Details

**Subject:** 
`Cortex Code Snowsight Billing Discrepancy - Documentation Says Free But Account Charged`

**Priority:** 
Medium (billing issue, non-urgent)

**Category:** 
Billing / Account Usage

**Description:**
Copy the "Issue Summary" and "Evidence of Charges" sections above.

---

## Attachments to Include

1. Screenshot of documentation stating "free"
2. Query results from CORTEX_AGENT_USAGE_HISTORY
3. Query results from REMAINING_BALANCE_DAILY
4. This document (optional)
