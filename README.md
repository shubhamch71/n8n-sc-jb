# DevOps Entry-Level Job Alerts - n8n Workflow

A production-ready, source-agnostic n8n automation that dynamically scrapes entry-level DevOps/Cloud/Platform engineering jobs and sends alerts to Telegram.

## Key Design Principles

- **No hardcoded companies** - All sources are configured via data, not workflow nodes
- **Generic ATS handlers** - One handler per ATS type serves all companies using that ATS
- **Dynamic iteration** - Sources are processed via loop, not parallel static nodes
- **Config-driven** - Add/remove sources by editing configuration only

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Dynamic Job Alerts Workflow                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────┐    ┌─────────────────────┐    ┌─────────────────────────┐     │
│  │  Cron    │───▶│ Load Source Config  │───▶│  Iterate Sources        │     │
│  │ (hourly) │    │ (from static data)  │    │  (SplitInBatches)       │     │
│  └──────────┘    └─────────────────────┘    └───────────┬─────────────┘     │
│                                                         │                    │
│                           ┌─────────────────────────────┼──────────┐        │
│                           │         LOOP PER SOURCE     │          │        │
│                           │                             ▼          │        │
│                           │  ┌────────────────────────────────┐    │        │
│                           │  │      Rate Limit Wait           │    │        │
│                           │  │      (10-40 seconds)           │    │        │
│                           │  └────────────────────────────────┘    │        │
│                           │                             │          │        │
│                           │                             ▼          │        │
│                           │  ┌────────────────────────────────┐    │        │
│                           │  │      Route by ATS Type         │    │        │
│                           │  │      (Switch Node)             │    │        │
│                           │  └────────────────────────────────┘    │        │
│                           │         │   │   │   │   │   │          │        │
│                           │         ▼   ▼   ▼   ▼   ▼   ▼          │        │
│  ┌────────────────────────┼─────────────────────────────────────────┼──┐    │
│  │  GENERIC ATS HANDLERS (one per ATS type, handles ALL companies)  │  │    │
│  │                                                                   │  │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │  │    │
│  │  │ Greenhouse  │ │   Lever     │ │   Ashby     │ │ SmartRecr.  │ │  │    │
│  │  │  Handler    │ │  Handler    │ │  Handler    │ │  Handler    │ │  │    │
│  │  │             │ │             │ │             │ │             │ │  │    │
│  │  │ URL built   │ │ URL built   │ │ URL built   │ │ URL built   │ │  │    │
│  │  │ from config │ │ from config │ │ from config │ │ from config │ │  │    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │  │    │
│  │                                                                   │  │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────────┐ │  │    │
│  │  │  Workable   │ │  RemoteOK   │ │  Unsupported ATS Fallback   │ │  │    │
│  │  │  Handler    │ │  Handler    │ │  (logs error, continues)    │ │  │    │
│  │  └─────────────┘ └─────────────┘ └─────────────────────────────┘ │  │    │
│  └───────────────────────────────────────────────────────────────────┘  │    │
│                           │                             │          │        │
│                           │                             ▼          │        │
│                           │  ┌────────────────────────────────┐    │        │
│                           │  │   Generic Parser per ATS       │    │        │
│                           │  │   (normalizes to standard      │    │        │
│                           │  │    job object format)          │    │        │
│                           │  └────────────────────────────────┘    │        │
│                           │                             │          │        │
│                           │                             ▼          │        │
│                           │  ┌────────────────────────────────┐    │        │
│                           │  │   Collect Jobs                 │    │        │
│                           │  │   (accumulate in static data)  │    │        │
│                           │  └────────────────────────────────┘    │        │
│                           │                             │          │        │
│                           └─────────────────────────────┘          │        │
│                                                                              │
│                                      ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         POST-LOOP PROCESSING                         │    │
│  ├─────────────────────────────────────────────────────────────────────┤    │
│  │  Filter Jobs → Deduplicate → Format Messages → Send to Telegram     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Source Configuration Model

Each source entry follows this schema:

```json
{
  "ats": "greenhouse",           // ATS type (determines which handler to use)
  "board": "company-slug",       // Identifier used in the ATS URL
  "company": "Display Name",     // Human-readable name for alerts
  "enabled": true,               // Toggle without removing
  "notes": "Optional context"    // For your reference
}
```

### Supported ATS Types

| ATS Type | URL Pattern | Board Identifier |
|----------|-------------|------------------|
| `greenhouse` | `boards-api.greenhouse.io/v1/boards/{board}/jobs` | Board name from URL |
| `lever` | `api.lever.co/v0/postings/{board}` | Company slug |
| `ashby` | `api.ashbyhq.com/posting-api/job-board/{board}` | Board name |
| `smartrecruiters` | `api.smartrecruiters.com/v1/companies/{board}/postings` | Company ID |
| `workable` | `apply.workable.com/api/v1/widget/accounts/{board}` | Account slug |
| `remoteok` | `remoteok.com/api?tag={tag}` | Tag name (use `tag` instead of `board`) |

## How to Add New Sources

### Step 1: Identify the ATS

Visit the company's careers page and check the URL:

| URL Pattern | ATS Type |
|-------------|----------|
| `boards.greenhouse.io/company` | greenhouse |
| `jobs.lever.co/company` | lever |
| `jobs.ashbyhq.com/company` | ashby |
| `jobs.smartrecruiters.com/Company` | smartrecruiters |
| `apply.workable.com/company` | workable |

### Step 2: Find the Board Identifier

The identifier is usually in the URL path:
- `boards.greenhouse.io/hashicorp` → board = `hashicorp`
- `jobs.lever.co/twilio` → board = `twilio`

### Step 3: Test the API Endpoint

```bash
# Greenhouse
curl -s "https://boards-api.greenhouse.io/v1/boards/NEW_COMPANY/jobs" | jq '.jobs | length'

# Lever
curl -s "https://api.lever.co/v0/postings/NEW_COMPANY?mode=json" | jq 'length'

# Ashby
curl -s "https://api.ashbyhq.com/posting-api/job-board/NEW_COMPANY" | jq '.jobs | length'
```

### Step 4: Add to Configuration

Edit the `Load Source Configuration` node and add:

```javascript
{ ats: 'greenhouse', board: 'new-company', company: 'New Company', enabled: true },
```

**No other workflow changes required.**

## Example Source Configurations

### Greenhouse Companies

```json
{ "ats": "greenhouse", "board": "hashicorp", "company": "HashiCorp", "enabled": true }
{ "ats": "greenhouse", "board": "gitlab", "company": "GitLab", "enabled": true }
{ "ats": "greenhouse", "board": "cloudflare", "company": "Cloudflare", "enabled": true }
{ "ats": "greenhouse", "board": "datadog", "company": "Datadog", "enabled": true }
{ "ats": "greenhouse", "board": "stripe", "company": "Stripe", "enabled": true }
```

### Lever Companies

```json
{ "ats": "lever", "board": "twilio", "company": "Twilio", "enabled": true }
{ "ats": "lever", "board": "discord", "company": "Discord", "enabled": true }
{ "ats": "lever", "board": "vercel", "company": "Vercel", "enabled": true }
```

### Ashby Companies

```json
{ "ats": "ashby", "board": "ramp", "company": "Ramp", "enabled": true }
{ "ats": "ashby", "board": "plaid", "company": "Plaid", "enabled": true }
```

### SmartRecruiters Companies

```json
{ "ats": "smartrecruiters", "board": "Visa", "company": "Visa", "enabled": true }
{ "ats": "smartrecruiters", "board": "BOSCH", "company": "Bosch", "enabled": true }
```

### RemoteOK Tags

```json
{ "ats": "remoteok", "tag": "devops", "company": "RemoteOK", "enabled": true }
{ "ats": "remoteok", "tag": "kubernetes", "company": "RemoteOK", "enabled": true }
```

## Quick Start

### 1. Configure Environment

```bash
cp .env.example .env
# Edit .env with your Telegram bot token and chat ID
```

### 2. Test Telegram Setup

```bash
./test-telegram.sh
```

### 3. Start n8n

```bash
make start
# Or: docker-compose up -d
```

### 4. Import Workflow

1. Open `http://localhost:5678`
2. Go to **Workflows** → **Import from File**
3. Select `job-alerts-workflow.json`
4. Configure Telegram credentials
5. Activate the workflow

## Filtering Logic

### Included Roles (by title keywords)
- DevOps, Cloud Engineer, Platform Engineer
- Kubernetes, SRE, Infrastructure
- MLOps, AIOps, LLMOps
- Cloud Infrastructure, ML Infrastructure

### Seniority Detection

**Included automatically:**
- Titles with: Junior, Entry Level, Associate, Graduate, Trainee, Intern
- Descriptions with: "0-2 years", "1-3 years", "early career"

**Excluded automatically:**
- Titles with: Senior, Staff, Principal, Lead, Manager, Architect
- Descriptions with: "4+ years", "extensive experience"

### Location Filtering
- **Excluded:** Pakistan, Bangladesh, Sri Lanka, Syria
- **Included:** All other regions globally

## Deduplication

Jobs are deduplicated using a hash of:
- Job title (normalized)
- Company name (normalized)
- Location (normalized)

Hashes are stored in n8n static data with 30-day TTL.

## Rate Limiting & Safety

- 10-40 second random delay between sources
- Sequential processing (one source at a time)
- Continue on failure for individual sources
- User-Agent rotation

## Deployment

### Docker (Local)

```bash
docker-compose up -d
```

### Fly.io

```bash
fly auth login
fly apps create n8n-job-alerts
fly volumes create n8n_data --size 1 --region iad
fly secrets set TELEGRAM_BOT_TOKEN="your-token"
fly secrets set TELEGRAM_CHAT_ID="your-chat-id"
fly secrets set N8N_BASIC_AUTH_USER="admin"
fly secrets set N8N_BASIC_AUTH_PASSWORD="your-password"
fly deploy
```

## Adding a New ATS Type

To support a new ATS that's not currently handled:

1. Add a new case to the **Route by ATS Type** switch node
2. Create an HTTP Request node with the URL pattern (using `{{ $json.board }}` for dynamic substitution)
3. Create a parser node that normalizes responses to the standard job format
4. Connect to the **Collect Jobs** node

Standard job object format:

```javascript
{
  job_title: "DevOps Engineer",
  company: "Company Name",
  location: "City, Country",
  job_url: "https://...",
  source: "ATS Name",
  ats: "ats-type",
  board: "company-slug",
  description: "...",
  posted_at: "2026-01-31T00:00:00Z",
  job_id: "..."
}
```

## Troubleshooting

### No jobs being collected
1. Check workflow execution logs in n8n
2. Verify API endpoints are accessible: `make test`
3. Check if sources are enabled in configuration

### Telegram errors
1. Verify bot token: `./test-telegram.sh`
2. Ensure bot has access to the chat/group
3. Check chat ID format (groups start with `-`)

### Rate limiting issues
1. Reduce number of enabled sources
2. Increase wait time in Rate Limit Wait node
3. Disable problematic sources temporarily

## Files

| File | Purpose |
|------|---------|
| `job-alerts-workflow.json` | Main workflow (import this) |
| `sources.json` | Reference source configuration |
| `docker-compose.yml` | Docker setup |
| `fly.toml` | Fly.io deployment |
| `.env.example` | Environment template |
| `test-telegram.sh` | Telegram test script |
