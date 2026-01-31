# Setup Guide

Quick setup for the n8n Job Alerts system.

## Prerequisites

- Docker & Docker Compose
- Telegram account
- (Optional) API keys for enhanced features

## 1. Environment Variables

```bash
cp .env.example .env
```

Edit `.env` with your values:

### Required
| Variable | Description | How to Get |
|----------|-------------|------------|
| `TELEGRAM_BOT_TOKEN` | Bot API token | Message @BotFather, create bot |
| `TELEGRAM_CHAT_ID` | Your chat/group ID | Message @userinfobot |
| `N8N_BASIC_AUTH_PASSWORD` | n8n login password | Choose a secure password |

### Optional (Enhanced Features)
| Variable | Description | Free Tier |
|----------|-------------|-----------|
| `TAVILY_API_KEY` | Company discovery | 1000/month |
| `GEMINI_API_KEY` | Company extraction | 1000/day |
| `RAPIDAPI_KEY` | JSearch job aggregator | 500/month |
| `SERPAPI_KEY` | Backup job search | 100/month |

### Kill Switches (Defaults: enabled)
| Variable | Effect when `false` |
|----------|---------------------|
| `ENABLE_COMPANY_DISCOVERY` | Skip weekly company discovery |
| `ENABLE_AGGREGATOR_APIS` | Use only direct ATS scraping |
| `ENABLE_NOTIFICATIONS` | Scrape silently (no Telegram) |

## 2. Local Docker Setup

```bash
# Start n8n
make start

# View logs
make logs

# Stop
make stop
```

Access at: http://localhost:5678

## 3. Import Workflows

1. Open n8n UI
2. Go to **Workflows** > **Import from File**
3. Import in order:
   - `job-alerts-workflow.json` (main job discovery)
   - `company-discovery-workflow.json` (weekly company finder)
   - `bot-commands-workflow.json` (Telegram commands)
   - `health-monitor-workflow.json` (daily heartbeat)
4. For each workflow:
   - Open workflow settings
   - Set **Active** to ON
5. Create Telegram credential:
   - Go to **Credentials**
   - Add **Telegram API**
   - Name it exactly: `Telegram Bot`
   - Paste your bot token

## 4. Fly.io Deployment

```bash
# Login
fly auth login

# Create app (first time)
fly apps create n8n-job-alerts

# Set secrets
make secrets
# Or manually:
fly secrets set TELEGRAM_BOT_TOKEN=xxx TELEGRAM_CHAT_ID=xxx ...

# Deploy
make deploy
```

## 5. Add/Remove Companies

### Option A: Edit source list in n8n
1. Open `job-alerts-workflow.json`
2. Find the `Load Source Configuration` node
3. Edit the `sources` array

### Option B: Auto-discovery
Enable company discovery by providing `TAVILY_API_KEY` and `GEMINI_API_KEY`.
New companies are automatically added weekly.

### Supported ATS Types
| ATS | URL Pattern |
|-----|-------------|
| `greenhouse` | `boards.greenhouse.io/{board}` |
| `lever` | `jobs.lever.co/{board}` |
| `ashby` | `jobs.ashbyhq.com/{board}` |
| `smartrecruiters` | `jobs.smartrecruiters.com/{board}` |
| `workable` | `apply.workable.com/{board}` |
| `remoteok` | Uses tags: devops, cloud, sre, kubernetes |

### Adding a Company
```javascript
{ ats: 'greenhouse', board: 'company-slug', company: 'Company Name', enabled: true }
```

Find the board slug from the company's careers page URL.

## 6. Telegram Commands

| Command | Action |
|---------|--------|
| `/usage` | Show API usage dashboard |
| `/pause` | Pause notifications (scraping continues) |
| `/resume` | Resume notifications |
| `/status` | Show system status and kill switches |

## 7. Workflow Schedules

| Workflow | Schedule | Purpose |
|----------|----------|---------|
| Job Discovery | Every 2 hours | Scrape jobs, send alerts |
| Company Discovery | Sunday 2 AM UTC | Find new companies |
| Health Monitor | Daily 8 AM UTC | System heartbeat |
| Bot Commands | On-demand | Handle Telegram commands |

## Troubleshooting

### No jobs found
- Check that workflows are active
- Verify Telegram credentials are correct
- Check n8n execution logs

### Rate limited
- JSearch/SerpApi have monthly limits
- Direct ATS scraping is unlimited
- Check `/usage` for current quotas

### Test Telegram
```bash
./test-telegram.sh
```

## Quick Reference

```bash
# Start locally
make start

# Deploy to Fly.io
make deploy

# View logs
make logs

# Test APIs
make test
```
