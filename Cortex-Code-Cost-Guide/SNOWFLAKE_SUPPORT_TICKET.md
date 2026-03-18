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
| Account Locator | <REDACTED> |
| Account Name | <REDACTED> |
| Organization | <REDACTED> |
| Region | <REDACTED> |
| Service Level | <REDACTED> |
| User | <YOUR_USERNAME> |

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

---

## CASE RESOLUTION (March 2026)

### Support Engineer: Snowflake Cloud Support Engineer

### Round 1 — Initial Response
- Cortex Code is "in preview and free" — AI token costs absorbed by Snowflake
- 10-credit daily cap is a trial account restriction, not real billing
- Trial credits consumed first, card charged only after exhaustion
- Suggested adding payment method to lift the cap
- **Error**: Stated OpenFlow is NOT available on trial accounts even after adding card

### Round 2 — After Adding Card (Issues Found)
- OpenFlow IS visible after adding card (contradicting Round 1)
- Trial balance tile disappeared from sidebar
- No self-service option to remove credit card (only "Replace")
- Support acknowledged the error and apologized

### Round 3 — Final Confirmed Facts
- **Trial end date**: June 23, 2026 (unchanged after adding card)
- **Original credit allocation**: 400 credits (unchanged)
- **ALL features consume trial credits first** — no feature bypasses trial balance
- **Card only charged after**: trial credits exhausted OR trial period ends
- **Cortex Code**: GA and FREE, advance notice before any billing introduced
- **Refund process**: If unexpected charge occurs, open Support case for refund
- **Credit card removal**: Not possible without closing account entirely
- **OpenFlow correction**: Visible after conversion but only charges if you create & run a connector
- **Trial tile disappearing**: Expected behavior after conversion to paid account
- **Product suggestions forwarded**: 4 suggestions documented and sent to product team

### Key Takeaways
1. Support was transparent and corrected errors promptly
2. All confirmations received in writing via email
3. Refund safety net exists for unexpected charges
4. Credit card is permanently locked in — cannot be removed without account closure
