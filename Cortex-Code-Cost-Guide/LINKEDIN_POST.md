# LinkedIn Post Draft — Final Version (March 2026)

---

## The Post

**Snowflake's Cortex Code: "10 credits reached" — I investigated, opened a Support case, and here's the full truth.**

As a student exploring Snowflake for career development, I hit this message:

> "Credit limit of 10 credits reached (10.36 credits used in the last 24 hours). Add a payment method to lift this limit."

Panic. Am I losing my trial credits? Is Cortex Code really free?

I did what any data person would do — I ran queries.

METERING_DAILY_HISTORY → No AI_SERVICES usage.
CORTEX_AISQL_USAGE_HISTORY → Empty. Zero rows.
All service types → Only WAREHOUSE_METERING and COPY_FILES.

So where are the 10.36 credits? I opened a Snowflake Support case. After 3 rounds of emails, here's what was confirmed in writing:

**The Facts (Verified by Snowflake Support):**

1. Cortex Code in Snowsight is GA and FREE — AI token costs are absorbed by Snowflake
2. The "10 credits" is a RATE LIMITER for trial accounts — not real billing
3. NO credits are deducted from your trial balance for Cortex Code
4. Adding a payment method lifts the cap without ending your trial
5. ALL features consume trial credits first — card only charged after credits are exhausted or trial ends
6. Refund process exists if unexpected charges occur

**What they don't tell you upfront:**

- Adding a credit card PERMANENTLY locks it in — you cannot remove it, only replace it. Account closure required to remove.
- The trial balance tile DISAPPEARS from the sidebar after adding a card — you lose visibility into your remaining credits and trial end date.
- Premium features like OpenFlow become VISIBLE (Support initially said they wouldn't — they corrected this after I shared a screenshot).
- Trust Center scanners (CIS Benchmarks, Threat Intelligence) run SILENTLY in the background consuming serverless credits.

**My cost control setup:**

```sql
-- Daily resource monitor (recommended by Support)
CREATE RESOURCE MONITOR daily_credit_monitor
  WITH CREDIT_QUOTA = 5 FREQUENCY = DAILY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS ON 75 PERCENT DO NOTIFY ON 100 PERCENT DO NOTIFY;

-- Disable silent credit consumers
CALL SYSTEM$TRUST_CENTER_DISABLE_SCANNER_PACKAGE('CIS Benchmarks');
CALL SYSTEM$TRUST_CENTER_DISABLE_SCANNER_PACKAGE('Threat Intelligence');

-- Monitor your balance
SELECT USAGE_DATE, USAGE_TYPE, USAGE_IN_CURRENCY
FROM SNOWFLAKE.ORGANIZATION_USAGE.USAGE_IN_CURRENCY_DAILY
ORDER BY USAGE_DATE DESC;
```

**My suggestions to Snowflake (forwarded to product team):**

1. Allow credit card removal for COCo access only
2. Let users choose: "Upgrade now" vs "Upgrade after trial ends"
3. Keep premium features disabled on trial accounts even after adding a card
4. Deduct COCo usage from trial credits instead of a hard daily cap

**For students:** Cortex Code is the best way to learn Snowflake — it provides verified, context-aware guidance directly from the platform. Don't rely on unverified third-party resources that create more confusion. But be informed before you add that credit card.

Full cost control guide + SQL queries on my GitHub (link in comments).

Have you hit this limit? What did you do?

#Snowflake #CortexCode #DataEngineering #CloudCosts #StudentLife #LessonsLearned

---

## Hashtags

Primary: #Snowflake #CortexCode #DataEngineering
Secondary: #CloudCosts #AI #StudentLife #LessonsLearned #TechTips #CortexAI

## Post Timing

Best: Tuesday-Thursday, 8-10 AM or 12 PM your timezone

## Engagement Tips

1. Reply to every comment (boosts algorithm)
2. Pin GitHub link as first comment
3. Tag relevant Snowflake community members (optional)
4. Share the Support experience as a learning moment — NOT to blame anyone
