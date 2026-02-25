# Screenshot Guide

## Required Screenshots for GitHub & LinkedIn

### 1. Balance Drop Chart
**Location:** Snowsight > Admin > Cost Management
**What to capture:**
- Graph showing balance over time
- Highlight the steep drop on Feb 23
- Make sure dates are visible

**Filename:** `01_balance_drop.png`

---

### 2. Cortex Agent Usage Results
**Query to run:**
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
**What to capture:** Query results showing token usage

**Filename:** `02_cortex_agent_usage.png`

---

### 3. Service Type Breakdown
**Query to run:**
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
**What to capture:** Pie/bar showing AI_SERVICES dominance

**Filename:** `03_service_breakdown.png`

---

### 4. Daily Spend Table
**What to capture:** The daily USD cost table
**Filename:** `04_daily_spend.png`

---

## Screenshot Tips

1. **Blur/redact sensitive info:**
   - Account name
   - User emails
   - Exact balance amounts (optional)

2. **Use consistent dimensions:**
   - 1200x630px (LinkedIn optimal)
   - Or 1920x1080 for GitHub

3. **Add annotations:**
   - Circle the key numbers
   - Add arrows to important drops

---

## Folder Structure for GitHub

```
cortex-code-cost-guide/
├── README.md
├── cost_analysis_queries.sql
├── screenshots/
│   ├── 01_balance_drop.png
│   ├── 02_cortex_agent_usage.png
│   ├── 03_service_breakdown.png
│   └── 04_daily_spend.png
└── LICENSE
```
