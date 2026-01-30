# Multi-Layer Job Discovery Architecture

## Overview

This system implements a 4-layer approach to discover entry-level DevOps/MLOps/Platform Engineering jobs with maximum coverage and zero duplicates.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              COMPLETE SYSTEM FLOW                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ╔═══════════════════════════════════════════════════════════════════════════╗ │
│   ║  WORKFLOW 1: COMPANY DISCOVERY (Weekly - Sunday 2 AM)                     ║ │
│   ║                                                                            ║ │
│   ║  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────────┐   ║ │
│   ║  │   Tavily    │───▶│   Gemini    │───▶│  Company List (Static Data) │   ║ │
│   ║  │  (Search)   │    │  (Extract)  │    │                              │   ║ │
│   ║  │             │    │             │    │  { company, ats, board }     │   ║ │
│   ║  │ "DevOps     │    │ Extract:    │    │  { company, ats, board }     │   ║ │
│   ║  │  startups"  │    │ - Name      │    │  { company, ats, board }     │   ║ │
│   ║  │             │    │ - Career URL│    │         ...                  │   ║ │
│   ║  │ "MLOps      │    │ - ATS type  │    │  (grows over time)           │   ║ │
│   ║  │  companies" │    │             │    │                              │   ║ │
│   ║  └─────────────┘    └─────────────┘    └─────────────────────────────┘   ║ │
│   ║                                                                            ║ │
│   ║  Cost: ~50 Tavily searches/week (free: 1000/month)                        ║ │
│   ║        ~50 Gemini calls/week (free: 1000/day)                             ║ │
│   ╚═══════════════════════════════════════════════════════════════════════════╝ │
│                                         │                                        │
│                                         ▼                                        │
│   ╔═══════════════════════════════════════════════════════════════════════════╗ │
│   ║  WORKFLOW 2: JOB DISCOVERY (Bi-Hourly - Every 2 Hours)                    ║ │
│   ║                                                                            ║ │
│   ║  ┌─────────────────────────────────────────────────────────────────────┐  ║ │
│   ║  │                    LAYER A: DIRECT ATS SCRAPING                     │  ║ │
│   ║  │                         (FREE - Unlimited)                          │  ║ │
│   ║  │                                                                      │  ║ │
│   ║  │  For each company in discovered list:                               │  ║ │
│   ║  │  ┌───────────┐ ┌───────┐ ┌───────┐ ┌─────────────┐ ┌───────────┐  │  ║ │
│   ║  │  │Greenhouse │ │ Lever │ │ Ashby │ │SmartRecruit │ │ Workable  │  │  ║ │
│   ║  │  │  Handler  │ │Handler│ │Handler│ │   Handler   │ │  Handler  │  │  ║ │
│   ║  │  └───────────┘ └───────┘ └───────┘ └─────────────┘ └───────────┘  │  ║ │
│   ║  │                                                                      │  ║ │
│   ║  │  → Scrapes ALL jobs from companies we know about                    │  ║ │
│   ║  │  → Zero API costs                                                   │  ║ │
│   ║  └─────────────────────────────────────────────────────────────────────┘  ║ │
│   ║                                         │                                  ║ │
│   ║                                         ▼                                  ║ │
│   ║  ┌─────────────────────────────────────────────────────────────────────┐  ║ │
│   ║  │                 LAYER B: JOB AGGREGATOR APIs                        │  ║ │
│   ║  │                    (Catches unknown companies)                      │  ║ │
│   ║  │                                                                      │  ║ │
│   ║  │  ┌─────────────────────────────────────────────────────────────┐   │  ║ │
│   ║  │  │  JSearch API (Primary) - 500 free/month                     │   │  ║ │
│   ║  │  │  Search: "junior devops", "entry level MLOps", etc.         │   │  ║ │
│   ║  │  │                                                              │   │  ║ │
│   ║  │  │  If rate limited (429) or quota exhausted:                  │   │  ║ │
│   ║  │  │           ↓                                                  │   │  ║ │
│   ║  │  │  SerpApi Google Jobs (Backup) - 100 free/month              │   │  ║ │
│   ║  │  │                                                              │   │  ║ │
│   ║  │  │  If also exhausted:                                         │   │  ║ │
│   ║  │  │           ↓                                                  │   │  ║ │
│   ║  │  │  Jobs Search API (Tertiary) - limited free                  │   │  ║ │
│   ║  │  └─────────────────────────────────────────────────────────────┘   │  ║ │
│   ║  │                                                                      │  ║ │
│   ║  │  → Finds jobs from companies NOT in our discovered list            │  ║ │
│   ║  │  → Automatic failover on rate limits                                │  ║ │
│   ║  └─────────────────────────────────────────────────────────────────────┘  ║ │
│   ║                                         │                                  ║ │
│   ║                                         ▼                                  ║ │
│   ║  ┌─────────────────────────────────────────────────────────────────────┐  ║ │
│   ║  │                    LAYER C: DEDUPLICATION                           │  ║ │
│   ║  │                                                                      │  ║ │
│   ║  │  Hash = SHA256(normalize(title + company + location))               │  ║ │
│   ║  │                                                                      │  ║ │
│   ║  │  ┌─────────────────────────────────────────────────────────────┐   │  ║ │
│   ║  │  │  Seen Hashes (Static Data)                                  │   │  ║ │
│   ║  │  │  ─────────────────────────────────────────────────────────  │   │  ║ │
│   ║  │  │  "a1b2c3d4" → { timestamp, source: "greenhouse" }           │   │  ║ │
│   ║  │  │  "e5f6g7h8" → { timestamp, source: "jsearch" }              │   │  ║ │
│   ║  │  │  "i9j0k1l2" → { timestamp, source: "lever" }                │   │  ║ │
│   ║  │  │                                                              │   │  ║ │
│   ║  │  │  → Same job from Layer A and Layer B? Only sent ONCE        │   │  ║ │
│   ║  │  │  → 30-day TTL for automatic cleanup                         │   │  ║ │
│   ║  │  └─────────────────────────────────────────────────────────────┘   │  ║ │
│   ║  └─────────────────────────────────────────────────────────────────────┘  ║ │
│   ║                                         │                                  ║ │
│   ║                                         ▼                                  ║ │
│   ║  ┌─────────────────────────────────────────────────────────────────────┐  ║ │
│   ║  │                    LAYER D: FILTERING                               │  ║ │
│   ║  │                                                                      │  ║ │
│   ║  │  ✓ Relevant keywords (DevOps, MLOps, Platform, Cloud, K8s, etc.)   │  ║ │
│   ║  │  ✓ Junior/Entry-level (title or 0-3 YOE in description)            │  ║ │
│   ║  │  ✗ Senior/Staff/Lead/Manager in title                              │  ║ │
│   ║  │  ✗ 4+ years experience in description                              │  ║ │
│   ║  │  ✗ Excluded locations (Pakistan, Bangladesh, Sri Lanka, Syria)     │  ║ │
│   ║  └─────────────────────────────────────────────────────────────────────┘  ║ │
│   ║                                         │                                  ║ │
│   ║                                         ▼                                  ║ │
│   ║  ┌─────────────────────────────────────────────────────────────────────┐  ║ │
│   ║  │                    OUTPUT: TELEGRAM (Optimized)                     │  ║ │
│   ║  │                                                                      │  ║ │
│   ║  │  See "Telegram Output Strategy" section below                       │  ║ │
│   ║  └─────────────────────────────────────────────────────────────────────┘  ║ │
│   ╚═══════════════════════════════════════════════════════════════════════════╝ │
│                                                                                  │
│   ╔═══════════════════════════════════════════════════════════════════════════╗ │
│   ║  WORKFLOW 3: API USAGE DASHBOARD (On-Demand via Telegram Command)        ║ │
│   ║                                                                            ║ │
│   ║  Send "/usage" to bot → Receive current API usage stats                   ║ │
│   ╚═══════════════════════════════════════════════════════════════════════════╝ │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Telegram Output Strategy (Optimized for Maximum Jobs)

### Problem with Simple Batching
- Telegram limit: 4096 characters per message
- Simple approach: Fixed 7 jobs per message wastes space
- Result: More messages, slower delivery, worse UX

### Optimized Strategy: Compact Format + Smart Batching

```
┌─────────────────────────────────────────────────────────────────┐
│                 TELEGRAM MESSAGE FORMATS                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  FORMAT 1: COMPACT (Default - Max ~15-20 jobs per message)      │
│  ─────────────────────────────────────────────────────────────  │
│                                                                  │
│  🚀 *12 New DevOps Jobs Found*                                  │
│                                                                  │
│  1. Junior DevOps Engineer                                       │
│     📍 Modal • Remote • [Apply](url)                            │
│                                                                  │
│  2. Entry Level Cloud Engineer                                   │
│     📍 Vercel • San Francisco • [Apply](url)                    │
│                                                                  │
│  3. Associate Platform Engineer                                  │
│     📍 Datadog • New York • [Apply](url)                        │
│                                                                  │
│  ... (continues)                                                 │
│                                                                  │
│  ─────────────────────────────────────────────────────────────  │
│  ~200 chars per job = ~20 jobs per 4000-char message            │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  FORMAT 2: DETAILED (For daily digest or fewer jobs)            │
│  ─────────────────────────────────────────────────────────────  │
│                                                                  │
│  *Junior DevOps Engineer*                                        │
│  🏢 Company: Modal                                               │
│  📍 Location: San Francisco (Remote OK)                         │
│  🔧 Source: Lever                                                │
│  🔗 [Apply Here](url)                                            │
│  ───────────────                                                 │
│                                                                  │
│  ~350 chars per job = ~10 jobs per message                      │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  FORMAT 3: ULTRA-COMPACT (For high-volume alerts)               │
│  ─────────────────────────────────────────────────────────────  │
│                                                                  │
│  🚀 *25 New Jobs*                                                │
│                                                                  │
│  • [Jr DevOps](url) @ Modal (Remote)                            │
│  • [Cloud Eng](url) @ Vercel (SF)                               │
│  • [Platform](url) @ Datadog (NYC)                              │
│  • [MLOps](url) @ Anyscale (Remote)                             │
│  ...                                                             │
│                                                                  │
│  ~100 chars per job = ~35 jobs per message                      │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SMART BATCHING LOGIC:                                          │
│                                                                  │
│  if (jobCount <= 10) → Use FORMAT 2 (Detailed)                  │
│  if (jobCount <= 25) → Use FORMAT 1 (Compact)                   │
│  if (jobCount > 25)  → Use FORMAT 3 (Ultra-Compact)             │
│                                                                  │
│  Always: Fill messages to ~4000 chars before creating new one   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Daily Digest Option

Instead of sending jobs immediately, accumulate and send once daily:

```
┌─────────────────────────────────────────────────────────────────┐
│                    DAILY DIGEST (8 AM)                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📊 *Daily Job Digest - Jan 31, 2026*                           │
│                                                                  │
│  Found *47 new jobs* across 23 companies                        │
│                                                                  │
│  *By Category:*                                                  │
│  • DevOps: 18 jobs                                               │
│  • Platform Engineering: 12 jobs                                 │
│  • MLOps/AI Infra: 9 jobs                                       │
│  • Cloud Engineering: 8 jobs                                     │
│                                                                  │
│  *Top Companies Hiring:*                                         │
│  • Datadog (5 positions)                                         │
│  • GitLab (4 positions)                                          │
│  • Modal (3 positions)                                           │
│                                                                  │
│  [View All Jobs](link-to-google-sheet-or-notion)                │
│                                                                  │
│  ───────────────────────────────────────────────────────────    │
│  Individual job messages follow...                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## API Usage Dashboard

### Workflow 3: Usage Monitor (Telegram Command)

User sends `/usage` to bot → Bot replies with current stats:

```
┌─────────────────────────────────────────────────────────────────┐
│                    /usage COMMAND RESPONSE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📊 *API Usage Dashboard*                                        │
│  Updated: Jan 31, 2026 14:30 UTC                                │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  *Tavily* (Company Discovery)                           │   │
│  │  ████████████░░░░░░░░ 156/1000 (15.6%)                  │   │
│  │  Resets: Feb 1, 2026                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  *Gemini* (Company Extraction)                          │   │
│  │  ██░░░░░░░░░░░░░░░░░░ 89/1000 (8.9%) today              │   │
│  │  Resets: Daily at midnight                              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  *JSearch* (Job Aggregator - Primary)                   │   │
│  │  █████████████████░░░ 423/500 (84.6%) ⚠️               │   │
│  │  Resets: Feb 1, 2026                                    │   │
│  │  Status: ACTIVE                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  *SerpApi* (Job Aggregator - Backup)                    │   │
│  │  █████████░░░░░░░░░░░ 45/100 (45%)                      │   │
│  │  Resets: Feb 1, 2026                                    │   │
│  │  Status: STANDBY                                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  *Direct ATS Scraping*                                  │   │
│  │  Companies tracked: 127                                  │   │
│  │  Last scrape: 14:00 UTC (47 jobs found)                 │   │
│  │  Status: ✅ UNLIMITED                                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  *This Month's Stats:*                                          │
│  • Total jobs discovered: 1,247                                  │
│  • After filtering: 312                                          │
│  • Sent to Telegram: 298                                         │
│  • New companies added: 12                                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Proactive Alerts

System automatically sends alerts when:

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROACTIVE ALERTS                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ⚠️ *API Quota Warning*                                         │
│                                                                  │
│  JSearch has reached 80% of monthly quota (400/500).            │
│  Switching to SerpApi for remaining searches.                   │
│                                                                  │
│  ───────────────────────────────────────────────────────────    │
│                                                                  │
│  ❌ *API Quota Exhausted*                                        │
│                                                                  │
│  All aggregator APIs exhausted for this month.                  │
│  Direct ATS scraping continues normally.                        │
│  APIs reset on Feb 1, 2026.                                     │
│                                                                  │
│  ───────────────────────────────────────────────────────────    │
│                                                                  │
│  ✅ *Monthly Reset Complete*                                     │
│                                                                  │
│  All API quotas have been reset for February 2026.              │
│  • Tavily: 0/1000                                                │
│  • JSearch: 0/500                                                │
│  • SerpApi: 0/100                                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## API Budget Breakdown (Monthly)

| API | Free Tier | Usage Pattern | Monthly Cost |
|-----|-----------|---------------|--------------|
| Tavily | 1,000/month | ~200 searches (4 weeks × 50 searches) | $0 |
| Gemini | 1,000/day | ~200 calls (for extraction) | $0 |
| JSearch | 500/month | ~400 job searches | $0 |
| SerpApi | 100/month | ~100 backup searches | $0 |
| Direct ATS | Unlimited | ~500 company scrapes | $0 |
| **Total** | | | **$0** |

---

## Data Models

### Company Entry (Discovered)

```javascript
{
  company: "Modal",
  ats: "lever",                    // greenhouse | lever | ashby | smartrecruiters | workable
  board: "modal",                  // identifier for ATS URL
  careers_url: "https://modal.com/careers",
  category: "AI Infrastructure",  // DevOps | MLOps | Platform | Cloud Native | AI Infra
  discovered_at: "2026-01-31T00:00:00Z",
  discovery_source: "tavily",     // tavily | manual | aggregator
  enabled: true,
  last_scraped: "2026-01-31T12:00:00Z"
}
```

### Job Entry (Normalized)

```javascript
{
  job_title: "Junior DevOps Engineer",
  company: "Modal",
  location: "San Francisco, CA (Remote)",
  job_url: "https://jobs.lever.co/modal/abc123",
  source: "lever",                // greenhouse | lever | jsearch | serpapi | etc.
  discovery_layer: "direct_ats",  // direct_ats | aggregator_api
  description: "...",
  posted_at: "2026-01-30T00:00:00Z",
  job_id: "abc123",
  hash: "a1b2c3d4e5f6..."         // for deduplication
}
```

### API Usage Tracking

```javascript
{
  jsearch: {
    used_this_month: 423,
    limit: 500,
    reset_date: "2026-02-01",
    last_error: null,
    is_exhausted: false,
    last_used: "2026-01-31T14:00:00Z"
  },
  serpapi: {
    used_this_month: 45,
    limit: 100,
    reset_date: "2026-02-01",
    last_error: null,
    is_exhausted: false,
    last_used: "2026-01-31T12:00:00Z"
  },
  tavily: {
    used_this_month: 156,
    limit: 1000,
    reset_date: "2026-02-01",
    last_error: null,
    is_exhausted: false,
    last_used: "2026-01-26T02:00:00Z"
  },
  gemini: {
    used_today: 89,
    limit_daily: 1000,
    last_error: null,
    last_used: "2026-01-31T02:30:00Z"
  },
  // Cumulative stats
  stats: {
    total_jobs_discovered: 1247,
    total_jobs_filtered: 312,
    total_jobs_sent: 298,
    total_companies_tracked: 127,
    new_companies_this_month: 12
  }
}
```

---

## Workflow Schedules

| Workflow | Schedule | Purpose |
|----------|----------|---------|
| Company Discovery | Weekly (Sunday 2 AM UTC) | Find new startups to track |
| Job Discovery | Bi-Hourly (Every 2 hours) | Scrape jobs and send alerts |
| API Usage Reset | Monthly (1st, 12 AM UTC) | Reset usage counters |
| Usage Dashboard | On-demand (/usage command) | Check API usage stats |

---

## Company Discovery Search Queries

The Company Discovery workflow searches for companies using these query categories:

### Category: DevOps/Infrastructure Startups

```
"DevOps startups founded 2023 2024 2025 2026"
"infrastructure automation startups 2024 2025 2026"
"CI/CD platform companies 2025 2026"
"GitOps startups 2024 2025 2026"
"developer tools startups Series A B 2025 2026"
"new DevOps companies 2026"
```

### Category: MLOps/AI Infrastructure

```
"MLOps startups 2024 2025 2026"
"AI infrastructure companies 2025 2026"
"ML platform startups 2024 2025 2026"
"LLMOps companies 2025 2026"
"AI developer tools startups 2025 2026"
"vector database startups 2024 2025 2026"
"new AI infrastructure companies 2026"
```

### Category: Cloud Native/Platform Engineering

```
"cloud native startups 2024 2025 2026"
"Kubernetes platform startups 2025 2026"
"platform engineering companies 2024 2025 2026"
"internal developer platform startups 2025 2026"
"cloud infrastructure startups 2024 2025 2026"
"new platform engineering startups 2026"
```

### Category: Observability/Monitoring

```
"observability startups 2024 2025 2026"
"monitoring platform companies 2025 2026"
"APM startups 2024 2025 2026"
"logging analytics startups 2025 2026"
"new observability companies 2026"
```

---

## Job Search Queries (Aggregator APIs)

```javascript
const searchQueries = [
  // Entry-level explicit
  "junior devops engineer",
  "entry level cloud engineer",
  "associate platform engineer",
  "junior site reliability engineer",
  "entry level MLOps engineer",
  "junior kubernetes engineer",
  "graduate cloud engineer",
  "intern devops",

  // Role-based (filter by YOE later)
  "devops engineer remote",
  "platform engineer",
  "MLOps engineer",
  "cloud infrastructure engineer",
  "site reliability engineer"
];
```

---

## Failover Logic

```
┌─────────────────────────────────────────────────────────────────┐
│                     API FAILOVER LOGIC                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  function getNextAvailableAPI() {                               │
│    const apis = ['jsearch', 'serpapi', 'jobs_search_api'];      │
│                                                                  │
│    for (const api of apis) {                                    │
│      const usage = getAPIUsage(api);                            │
│                                                                  │
│      // Check if exhausted                                      │
│      if (usage.is_exhausted) continue;                          │
│                                                                  │
│      // Check if near limit (90%)                               │
│      if (usage.used_this_month >= usage.limit * 0.9) {          │
│        markAsExhausted(api);                                    │
│        sendQuotaWarning(api);  // Alert user                    │
│        continue;                                                │
│      }                                                          │
│                                                                  │
│      return api;                                                │
│    }                                                            │
│                                                                  │
│    sendAllExhaustedAlert();  // Alert user                      │
│    return null; // All APIs exhausted                           │
│  }                                                              │
│                                                                  │
│  function handleAPIError(api, error) {                          │
│    if (error.status === 429 || error.code === 'QUOTA_EXCEEDED') │
│      markAsExhausted(api);                                      │
│      return getNextAvailableAPI();                              │
│    }                                                            │
│  }                                                              │
│                                                                  │
│  function incrementUsage(api) {                                 │
│    usage[api].used_this_month++;                                │
│    usage[api].last_used = new Date().toISOString();             │
│  }                                                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Environment Variables Required

```bash
# Telegram
TELEGRAM_BOT_TOKEN=your-bot-token
TELEGRAM_CHAT_ID=your-chat-id

# Tavily (Company Discovery)
TAVILY_API_KEY=your-tavily-key

# Google Gemini (Company Extraction)
GEMINI_API_KEY=your-gemini-key

# RapidAPI (JSearch)
RAPIDAPI_KEY=your-rapidapi-key

# SerpApi (Backup)
SERPAPI_KEY=your-serpapi-key

# n8n
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your-password
```

---

## File Structure

```
n8n/
├── workflows/
│   ├── company-discovery.json      # Weekly: Tavily + Gemini
│   ├── job-discovery.json          # Bi-Hourly: ATS + APIs + Telegram
│   └── usage-dashboard.json        # On-demand: /usage command handler
├── docker-compose.yml
├── fly.toml
├── .env.example
├── README.md
├── ARCHITECTURE.md                 # This file
├── SOURCES.md                      # How to add sources manually
└── test-telegram.sh
```

---

## Key Design Decisions

### 1. Why Three Workflows?

- **Company Discovery** is expensive (uses limited APIs) → Run weekly
- **Job Discovery** is cheap (direct scraping is free) → Run bi-hourly
- **Usage Dashboard** is on-demand → User-triggered via Telegram
- Separation allows independent scaling and debugging

### 2. Why Direct ATS Scraping First?

- It's FREE and unlimited
- We control exactly which companies we track
- More reliable than aggregator APIs
- Aggregator APIs are backup for companies we haven't discovered yet

### 3. Why Deduplicate Across All Sources?

- Same job posted on company site AND indexed by Google Jobs
- JSearch and SerpApi may return overlapping results
- User should never see the same job twice

### 4. Why Track API Usage?

- Prevent unexpected charges
- Automatic failover before hitting hard limits
- Visibility into which APIs are being used
- User can check anytime via /usage command

### 5. Why Bi-Hourly Instead of Hourly?

- Reduces API consumption by 50%
- Most job postings don't change within 1 hour
- Still provides timely alerts (max 2 hour delay)
- More sustainable for free tier limits

### 6. Why Smart Telegram Formatting?

- Maximize jobs per message (up to 35 with ultra-compact)
- Reduce notification spam
- Faster to scan for users
- Adapts based on volume

---

## Monitoring & Alerts

The system automatically tracks and reports:

### Logged Metrics
- Number of companies discovered (weekly)
- Number of jobs scraped per source
- API usage levels (updated after each call)
- Errors and failures
- Jobs sent to Telegram

### Telegram Alerts (Automatic)
- API approaching quota limit (80%)
- API quota exhausted (failover activated)
- All APIs exhausted (direct ATS only mode)
- Monthly reset complete
- Discovery workflow found new companies
- Critical errors in scraping

### On-Demand Dashboard (/usage)
- Current usage for all APIs
- Visual progress bars
- Days until reset
- Monthly statistics
- Active/Standby/Exhausted status
