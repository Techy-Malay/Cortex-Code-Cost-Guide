# LinkedIn Post Draft

---

## Option 1: Short & Punchy

**I lost 50% of my Snowflake credits in 3 days. Here's what happened.**

Everyone talks about Cortex Code being amazing. Nobody talks about the bill.

3 days. $112 USD. Gone.

The culprit? Cortex Agent tokens. Every prompt. Every response. Charged.

Plot twist: The documentation says "Cortex Code in Snowsight is currently free of charge."
My REMAINING_BALANCE_DAILY view disagrees. 🤔

What I learned:
- Cortex Code is NOT free (even in preview)
- 265 requests = $80 in one day
- Input + Output tokens = real money
- Documentation and billing may not match - verify!

Tips that actually work:
1. Keep prompts short
2. Say "just SQL" - skip the analysis
3. Batch your questions
4. Analyze results yourself

Control access:
```sql
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE analyst_role;
```

I built a GitHub repo with SQL queries to track YOUR Cortex costs before you get surprised.

Link in comments.

#Snowflake #CortexCode #DataEngineering #CloudCosts #LessonsLearned

---

## Option 2: Story Format

**"It's free during preview" - Famous last words.**

Last week I was exploring Snowflake's Cortex Code. Amazing tool. AI-powered SQL assistant. What's not to love?

Then I checked my balance.

Day 1: $312
Day 3: $201

$112 gone. In 72 hours.

Here's the breakdown:
- Feb 22: $0.64
- Feb 23: $79.89 (265 AI requests)
- Feb 24: $31.48

The math: 9.2 million tokens processed = real charges.

What nobody told me:
- Every prompt = input tokens (charged)
- Every response = output tokens (charged)
- Writing to file = same response, NOT double charged
- BUT asking to write later = NEW charge

My cost-saving playbook:
1. Be concise - "SQL for warehouse costs" not "Can you please write me a query..."
2. Skip analysis - Run queries yourself
3. One request > multiple follow-ups

I've open-sourced my cost tracking queries on GitHub.

Don't learn this the expensive way.

#Snowflake #AI #CortexCode #CloudCosts #DataEngineering

---

## Hashtags to Use

Primary:
- #Snowflake
- #CortexCode
- #DataEngineering

Secondary:
- #CloudCosts
- #AI
- #MachineLearning
- #DataAnalytics
- #TechTips

---

## Post Timing

Best times for LinkedIn engagement:
- Tuesday-Thursday
- 8-10 AM or 12 PM (your timezone)
- Avoid weekends

---

## Engagement Tips

1. Reply to every comment (boosts algorithm)
2. Ask a question at the end: "Have you checked YOUR Cortex costs?"
3. Pin your GitHub link as first comment
4. Tag relevant Snowflake influencers (optional)
