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
│   ║  WORKFLOW 2: JOB DISCOVERY (Hourly)                                       ║ │
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
│   ║  │                    OUTPUT: TELEGRAM                                 │  ║ │
│   ║  │                                                                      │  ║ │
│   ║  │  • Batched messages (max 3500 chars, 7 jobs per message)           │  ║ │
│   ║  │  • MarkdownV2 formatting                                            │  ║ │
│   ║  │  • Includes job source for transparency                             │  ║ │
│   ║  └─────────────────────────────────────────────────────────────────────┘  ║ │
│   ╚═══════════════════════════════════════════════════════════════════════════╝ │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## API Budget Breakdown (Monthly)

| API | Free Tier | Usage Pattern | Monthly Cost |
|-----|-----------|---------------|--------------|
| Tavily | 1,000/month | ~200 searches (4 weeks × 50 searches) | $0 |
| Gemini | 1,000/day | ~200 calls (for extraction) | $0 |
| JSearch | 500/month | ~400 job searches | $0 |
| SerpApi | 100/month | ~100 backup searches | $0 |
| Direct ATS | Unlimited | ~500 company scrapes | $0 |
| **Total** | | | **$0** |

## Data Models

### Company Entry (Discovered)

```javascript
{
  company: "Modal",
  ats: "lever",                    // greenhouse | lever | ashby | smartrecruiters | workable
  board: "modal",                  // identifier for ATS URL
  careers_url: "https://modal.com/careers",
  category: "AI Infrastructure",  // DevOps | MLOps | Platform | Cloud Native | AI Infra
  discovered_at: "2025-01-31T00:00:00Z",
  discovery_source: "tavily",     // tavily | manual | aggregator
  enabled: true,
  last_scraped: "2025-01-31T12:00:00Z"
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
  posted_at: "2025-01-30T00:00:00Z",
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
    reset_date: "2025-02-01",
    last_error: null,
    is_exhausted: false
  },
  serpapi: {
    used_this_month: 45,
    limit: 100,
    reset_date: "2025-02-01",
    last_error: null,
    is_exhausted: false
  },
  tavily: {
    used_this_month: 156,
    limit: 1000,
    reset_date: "2025-02-01",
    last_error: null,
    is_exhausted: false
  }
}
```

## Workflow Schedules

| Workflow | Schedule | Purpose |
|----------|----------|---------|
| Company Discovery | Weekly (Sunday 2 AM UTC) | Find new startups to track |
| Job Discovery | Hourly | Scrape jobs and send alerts |
| API Usage Reset | Monthly (1st, 12 AM UTC) | Reset usage counters |

## Company Discovery Search Queries

The Company Discovery workflow searches for companies using these query categories:

### Category: DevOps/Infrastructure Startups

```
"DevOps startups founded 2023 2024 2025"
"infrastructure automation startups"
"CI/CD platform companies"
"GitOps startups"
"developer tools startups Series A B"
```

### Category: MLOps/AI Infrastructure

```
"MLOps startups 2024 2025"
"AI infrastructure companies"
"ML platform startups"
"LLMOps companies"
"AI developer tools startups"
"vector database startups"
```

### Category: Cloud Native/Platform Engineering

```
"cloud native startups"
"Kubernetes platform startups"
"platform engineering companies"
"internal developer platform startups"
"cloud infrastructure startups"
```

### Category: Observability/Monitoring

```
"observability startups"
"monitoring platform companies"
"APM startups"
"logging analytics startups"
```

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
│        continue;                                                │
│      }                                                          │
│                                                                  │
│      return api;                                                │
│    }                                                            │
│                                                                  │
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
└─────────────────────────────────────────────────────────────────┘
```

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

## File Structure

```
n8n/
├── workflows/
│   ├── company-discovery.json      # Weekly: Tavily + Gemini
│   └── job-discovery.json          # Hourly: ATS + APIs + Telegram
├── docker-compose.yml
├── fly.toml
├── .env.example
├── README.md
├── ARCHITECTURE.md                 # This file
├── SOURCES.md                      # How to add sources manually
└── test-telegram.sh
```

## Key Design Decisions

### 1. Why Two Workflows?

- **Company Discovery** is expensive (uses paid-tier-limited APIs) → Run weekly
- **Job Discovery** is cheap (direct scraping is free) → Run hourly
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

## Monitoring & Alerts

The system logs:
- Number of companies discovered (weekly)
- Number of jobs scraped per source
- API usage levels
- Errors and failures
- Jobs sent to Telegram

Consider adding Telegram alerts for:
- API approaching quota limit (80%)
- Discovery workflow found new companies
- Errors in scraping
