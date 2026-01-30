# DevOps Entry-Level Job Alerts - n8n Workflow

A production-ready n8n automation that scrapes entry-level DevOps/Cloud/Platform engineering jobs from multiple ATS platforms and sends alerts to Telegram.

## Features

- Scrapes 13+ job sources (Greenhouse, Lever, RemoteOK)
- Smart filtering for entry-level/early-career roles
- Deduplication across runs using n8n static data
- Rate-limiting and anti-ban protections
- Telegram notifications with proper batching
- Docker and Fly.io compatible

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         n8n Job Alerts Workflow                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────┐    ┌────────┐    ┌─────────────────────────────────────┐  │
│  │  Cron    │───▶│ Config │───▶│  HTTP Request Nodes (13 sources)   │  │
│  │ (hourly) │    │  Init  │    │  - Greenhouse APIs                  │  │
│  └──────────┘    └────────┘    │  - Lever APIs                       │  │
│                                │  - RemoteOK API                     │  │
│                                └─────────────────────────────────────┘  │
│                                              │                           │
│                                              ▼                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                     Normalize All Jobs                           │    │
│  │  - Standardize fields (title, company, location, url)           │    │
│  │  - Handle different API response formats                         │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                              │                           │
│                                              ▼                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                        Filter Jobs                               │    │
│  │  - Match DevOps/Cloud/Platform keywords                          │    │
│  │  - Include junior/entry-level indicators                         │    │
│  │  - Exclude senior/lead/manager titles                            │    │
│  │  - Filter excluded locations                                     │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                              │                           │
│                                              ▼                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      Deduplicate Jobs                            │    │
│  │  - Hash: title + company + location                              │    │
│  │  - Store in n8n static data                                      │    │
│  │  - Auto-cleanup after 30 days                                    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                              │                           │
│                          ┌───────────────────┴───────────────────┐      │
│                          ▼                                       ▼      │
│                   [Has New Jobs?]                         [No Jobs]     │
│                          │                                       │      │
│                          ▼                                       ▼      │
│  ┌─────────────────────────────────┐         ┌──────────────────────┐  │
│  │  Format Telegram Messages       │         │  Log & Skip          │  │
│  │  - Batch by character limit     │         └──────────────────────┘  │
│  │  - Max 3500 chars per message   │                                    │
│  │  - Max 7 jobs per message       │                                    │
│  └─────────────────────────────────┘                                    │
│                          │                                              │
│                          ▼                                              │
│  ┌─────────────────────────────────┐                                    │
│  │  Send to Telegram               │                                    │
│  │  - Sequential with delays       │                                    │
│  │  - MarkdownV2 formatting        │                                    │
│  └─────────────────────────────────┘                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Job Sources

### Currently Configured

| Source | Companies | API Type |
|--------|-----------|----------|
| Greenhouse | HashiCorp, GitLab, Cloudflare, Datadog, MongoDB, Elastic, CockroachDB | JSON API |
| Lever | Twilio, Figma, Netflix | JSON API |
| RemoteOK | DevOps, Cloud, SRE tags | JSON API |

### Adding New Sources

The workflow is designed to be extensible. To add a new source:

1. **Greenhouse Companies**: Change the board name in the URL
   ```
   https://boards-api.greenhouse.io/v1/boards/{company-name}/jobs
   ```

2. **Lever Companies**: Change the company slug
   ```
   https://api.lever.co/v0/postings/{company-slug}?mode=json
   ```

3. **Other ATS**: Add HTTP Request nodes with appropriate parsing in the "Normalize All Jobs" code node

## Setup Guide

### Step 1: Create a Telegram Bot

1. Open Telegram and search for `@BotFather`
2. Send `/newbot` and follow the prompts
3. Choose a name (e.g., "DevOps Job Alerts")
4. Choose a username (e.g., "devops_jobs_alert_bot")
5. **Save the bot token** - looks like: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`

### Step 2: Get Your Chat ID

**Option A: Personal Chat ID**
1. Search for `@userinfobot` or `@getidsbot` on Telegram
2. Start a chat and it will show your user ID
3. This is your `TELEGRAM_CHAT_ID`

**Option B: Group Chat ID**
1. Add your bot to the group
2. Add `@getidsbot` to the group temporarily
3. The bot will show the group ID (starts with `-`)
4. Remove `@getidsbot` after getting the ID

### Step 3: Set Up Environment Variables

```bash
cp .env.example .env
```

Edit `.env` with your values:
```env
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_ID=987654321
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your-secure-password
```

### Step 4: Run with Docker

```bash
# Start n8n
docker-compose up -d

# Check logs
docker-compose logs -f n8n

# Access n8n UI
open http://localhost:5678
```

### Step 5: Import the Workflow

1. Open n8n at `http://localhost:5678`
2. Log in with your credentials
3. Go to **Workflows** > **Import from File**
4. Select `job-alerts-workflow.json`
5. Click **Import**

### Step 6: Configure Telegram Credentials

1. In the workflow, click on the **"Send to Telegram"** node
2. Click on **Credentials** > **Create New**
3. Enter your bot token
4. Click **Save**

### Step 7: Activate the Workflow

1. Toggle the workflow to **Active** (top right)
2. The workflow will now run every hour

## Fly.io Deployment

### Prerequisites

1. Install the Fly CLI: https://fly.io/docs/hands-on/install-flyctl/
2. Sign up for Fly.io (free tier available)

### Deployment Steps

```bash
# Login to Fly.io
fly auth login

# Create the app (first time only)
fly apps create n8n-job-alerts

# Create persistent volume for data
fly volumes create n8n_data --size 1 --region iad

# Set secrets (environment variables)
fly secrets set TELEGRAM_BOT_TOKEN="your-bot-token"
fly secrets set TELEGRAM_CHAT_ID="your-chat-id"
fly secrets set N8N_BASIC_AUTH_USER="admin"
fly secrets set N8N_BASIC_AUTH_PASSWORD="your-secure-password"
fly secrets set WEBHOOK_URL="https://n8n-job-alerts.fly.dev/"

# Deploy
fly deploy

# Check status
fly status

# View logs
fly logs
```

### Access Your Deployment

Your n8n instance will be available at:
```
https://n8n-job-alerts.fly.dev
```

## Filtering Logic

### Included Roles (Title Keywords)
- DevOps
- Cloud Engineer
- Platform Engineer
- Kubernetes
- MLOps, AIOps, LLMOps
- Cloud Infrastructure
- ML Infrastructure
- Site Reliability (SRE)

### Seniority Detection

**Included if title contains:**
- Junior, Entry Level, Associate
- Graduate, Trainee, Intern

**Included if description mentions:**
- "0-1 years", "1-2 years", "1-3 years"
- "early career", "new graduate", "fresher"

**Excluded if title contains:**
- Senior, Staff, Principal
- Lead, Manager, Architect, Director

**Excluded if description mentions:**
- "4+ years", "5+ years", etc.
- "extensive experience", "senior-level"

### Location Filtering

**Excluded locations:**
- Pakistan, Bangladesh, Sri Lanka, Syria

**Included locations:**
- All other regions globally
- Remote positions

## Troubleshooting

### No Jobs Being Sent

1. **Check workflow execution**: Go to Executions tab in n8n
2. **Verify API responses**: Check if HTTP Request nodes return data
3. **Check filter logic**: May need to adjust keyword matching
4. **Deduplication**: On first run, all jobs are "new"; subsequent runs only send new ones

### Telegram Errors

1. **Invalid token**: Verify bot token is correct
2. **Chat not found**: Ensure chat ID is correct and bot has access
3. **Message too long**: Workflow already handles this, but check formatting

### Rate Limiting

The workflow includes built-in protections:
- Random wait (10-40s) before scraping
- Sequential HTTP requests
- Continue on failure for individual sources

### Viewing Logs

```bash
# Docker
docker-compose logs -f n8n

# Fly.io
fly logs
```

### Resetting Deduplication

To reset seen jobs and get all jobs again:

1. Stop the workflow
2. In the "Deduplicate Jobs" code node, add temporarily:
   ```javascript
   staticData.seenJobHashes = {};
   ```
3. Run once manually
4. Remove the line and reactivate

## Extending the Workflow

### Adding More Greenhouse Companies

Find company board names at `https://boards.greenhouse.io/{company}`

Common examples:
- `stripe`, `airbnb`, `dropbox`, `coinbase`, `plaid`
- `snowflake`, `databricks`, `confluent`

### Adding More Lever Companies

Find company slugs at `https://jobs.lever.co/{company}`

Common examples:
- `discord`, `notion`, `linear`, `vercel`

### Adding Indeed RSS (with caution)

```
https://www.indeed.com/rss?q=devops+junior&l=remote
```

Note: Indeed may block automated access.

### Custom ATS Integration

For company career pages with unique formats:
1. Add HTTP Request node
2. Add HTML Extract node if needed
3. Modify "Normalize All Jobs" to parse the format

## Performance Considerations

- **Memory**: ~512MB sufficient for normal operation
- **Storage**: SQLite database grows with execution history
- **Network**: ~50-100KB per run (API responses)
- **Execution time**: ~2-5 minutes per run

## Security Notes

1. Never commit `.env` files
2. Use strong passwords for n8n basic auth
3. Keep bot token secret
4. Consider IP restrictions on Fly.io

## License

This workflow is provided as-is for personal use. Respect the terms of service of the job boards and ATS platforms being scraped.
