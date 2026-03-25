# LinkedIn Post — Cortex Code Pricing: What Every Snowflake User Needs to Know

**Date:** 2026-03-24
**Topic:** Cortex Code in Snowsight moves from free preview to paid — April 1, 2026
**Audience:** Snowflake practitioners, data engineers, trial account users, cost-conscious teams

---

## Post

Snowflake Cortex Code is going paid on April 1, 2026. Here's what you need to know before it hits your wallet.

I've been using Cortex Code daily in Snowsight — it's an incredible AI coding assistant. But I recently opened a support ticket to understand the pricing model, and the answers are worth sharing.

**3 things every Snowflake user should know:**

**1. It's consumption-based, not subscription.**
You pay per token processed. No monthly fee. Every prompt, every response — tokens in, tokens out — costs credits. The rates are in Snowflake's Service Consumption Table. Small interactions add up fast if you're not watching.

**2. Trial account users: be extra careful — but there's good news.**
Cortex Code works on trial accounts, but you have a daily credit cap (around 10 credits). Once your trial converts to a paid account, that cap is removed. This means your AI usage can now consume credits without a safety net unless you set one up yourself.

**But here's the part that matters for students and learners:**
I confirmed directly with Snowflake Support — when you convert a trial to a paid account:
- Your **unused trial credits carry over**. They don't vanish.
- Snowflake **consumes trial credits first** before charging your credit card.
- Trial credits remain valid until exhausted **or** the trial period ends (30 days standard / 120 days for Student Edition) — whichever comes first.

This means you can safely convert to paid and keep exploring without immediately incurring charges. Snowflake genuinely cares about learners having room to experiment.

**3. You can (and should) monitor it.**
Snowflake added a dedicated view for this:

```sql
SELECT USER_ID, SUM(TOKEN_CREDITS) AS TOTAL_CREDITS
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
WHERE USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY USER_ID
ORDER BY TOTAL_CREDITS DESC;
```

This tells you exactly who is consuming what.

**A word of caution: adding a credit card = converting to paid.**
The moment you add a credit card, your trial becomes a paid account. The daily credit cap is removed. Your trial credits still apply, but once they're gone — or the trial period expires — real charges begin. Don't add a credit card unless you understand this. If you have any questions or concerns, reach out to Snowflake Support first — they are genuinely helpful and responsive.

**My recommendations if you're converting from trial to paid:**

- Before adding a credit card, contact Snowflake Support with any billing or credit questions — they respond fast and will clarify everything
- Set up a Resource Monitor IMMEDIATELY — even a simple daily 5-credit cap with alerts at 50%, 75%, 100%
- Disable silent credit consumers (Trust Center scanners like CIS Benchmarks and Threat Intelligence eat serverless credits in the background)
- Set AUTO_SUSPEND = 60 on all warehouses
- Run the monitoring query above weekly
- Check USAGE_IN_CURRENCY_DAILY for the full picture (warehouse + AI + serverless — all in USD)

**The bigger picture:**
Cortex Code is powerful. But "consumption-based" means there's no upper bound unless you create one. The difference between a $5/month habit and a $500/month surprise is monitoring.

Don't wait until your invoice arrives.

---

#Snowflake #CortexCode #DataEngineering #CloudCosts #SnowflakeAI #CostOptimization #FinOps #DataPlatform #SnowsightAI #CreditManagement

---

## Key Facts (from Snowflake Support)

| Question | Answer |
|----------|--------|
| When does billing start? | April 1, 2026 |
| Pricing model | Consumption-based (tokens processed → credits) |
| Available on trial accounts? | Yes, with daily credit cap (~10 credits) |
| Trial credits after conversion? | Carry over — consumed first before paid credits |
| Trial credit validity | Until exhausted OR trial period ends (30 days / 120 days Student Edition) |
| Subscription model? | No — standard Snowflake credit consumption |
| Monitoring view | `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` |
| Rate details | Snowflake Service Consumption Table (PDF) |

## Docs References
- Cortex Code in Snowsight: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-snowsight
- Usage Monitoring View: https://docs.snowflake.com/en/sql-reference/account-usage/cortex_code_snowsight_usage_history
- Trial Accounts Documentation: https://docs.snowflake.com/en/user-guide/admin-trial-account

---

## Support Ticket — Trial Credit Confirmation (CONFIRMED)

**Status:** Confirmed by Snowflake Support 

| Question | Confirmed Answer |
|----------|------------------|
| Do unused trial credits carry over after conversion? | **Yes.** Adding a credit card converts to paid without ending the trial. Remaining free credits stay available. |
| Are trial credits consumed first? | **Yes.** During the trial period, free credits are consumed first. Once depleted, charges go to the credit card. |
| How long do trial credits last? | Until whichever comes first: free balance fully depleted, or the original trial period ends (30 days / 120 days Student Edition). Unused balance expires when trial period ends. |

**Bottom line:** Converting to paid lets you keep exploring on trial credits for the remainder of the trial period without immediately incurring paid charges.

**Reference:** https://docs.snowflake.com/en/user-guide/admin-trial-account
