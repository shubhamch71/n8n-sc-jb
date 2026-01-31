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

## 4. Fly.io First-Time Setup (One-Time)

Run these commands **once** before using CI/CD:

### Step 1: Create App

```bash
fly auth login
fly apps create n8n-job-alerts
```

### Step 2: Create Persistent Volume

```bash
fly volumes create n8n_data --region iad --size 1 --app n8n-job-alerts
```

This creates storage on Fly.io cloud (not locally) for:
- SQLite database
- n8n credentials
- Workflow executions
- Seen job hashes

### Step 3: Set Secrets

```bash
fly secrets set \
  TELEGRAM_BOT_TOKEN="your-bot-token" \
  TELEGRAM_CHAT_ID="your-chat-id" \
  N8N_BASIC_AUTH_USER="admin" \
  N8N_BASIC_AUTH_PASSWORD="your-secure-password" \
  --app n8n-job-alerts
```

Optional secrets:
```bash
fly secrets set \
  TAVILY_API_KEY="xxx" \
  GEMINI_API_KEY="xxx" \
  RAPIDAPI_KEY="xxx" \
  SERPAPI_KEY="xxx" \
  --app n8n-job-alerts
```

### Step 4: First Deploy

```bash
fly deploy
```

### Step 5: Get Deploy Token for GitHub

```bash
fly tokens create deploy -x 999999h
# Copy this token for GitHub Actions
```

## 5. CI/CD Deployment (GitHub Actions)

After first-time setup, pushes to `main` auto-deploy:

```
git push main → GitHub Actions → fly deploy → Fly.io
```

### Configure GitHub Secrets

Go to: **Repository → Settings → Secrets and variables → Actions**

**Required Secrets:**

| Secret | Description | How to Get |
|--------|-------------|------------|
| `FLY_API_TOKEN` | Fly.io deploy token | Step 1 above |
| `TELEGRAM_BOT_TOKEN` | Bot API token | @BotFather |
| `TELEGRAM_CHAT_ID` | Chat/group ID | @userinfobot |
| `N8N_BASIC_AUTH_USER` | n8n username | Choose (e.g., `admin`) |
| `N8N_BASIC_AUTH_PASSWORD` | n8n password | Choose secure password |

**Optional Secrets:**

| Secret | Description |
|--------|-------------|
| `TAVILY_API_KEY` | Company discovery API |
| `GEMINI_API_KEY` | AI extraction |
| `RAPIDAPI_KEY` | JSearch aggregator |
| `SERPAPI_KEY` | Backup search |

### Step 3: Configure GitHub Variables

Go to: **Repository → Settings → Secrets and variables → Actions → Variables**

| Variable | Value | Description |
|----------|-------|-------------|
| `ENABLE_COMPANY_DISCOVERY` | `true` | Enable company discovery |
| `ENABLE_AGGREGATOR_APIS` | `true` | Enable JSearch/SerpApi |
| `ENABLE_NOTIFICATIONS` | `true` | Enable Telegram alerts |

### Step 4: Deploy

Push to main branch:
```bash
git add .
git commit -m "Deploy"
git push origin main
```

Check deployment: **Repository → Actions tab**

### Manual Secret Sync

To update Fly.io secrets from GitHub:
1. Go to **Actions → "Sync Secrets to Fly.io"**
2. Click **Run workflow**
3. Type `sync` to confirm
4. Click **Run workflow**

## 6. Add/Remove Companies

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

## 7. Telegram Commands

| Command | Action |
|---------|--------|
| `/usage` | Show API usage dashboard |
| `/pause` | Pause notifications (scraping continues) |
| `/resume` | Resume notifications |
| `/status` | Show system status and kill switches |

## 8. Workflow Schedules

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
