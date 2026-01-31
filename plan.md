# Task: Make sources.json the Single Source of Truth for Companies

## Project Overview
This is an n8n job alerts system deployed on Fly.io that:
- Discovers DevOps/MLOps companies via Tavily + Gemini (weekly)
- Scrapes jobs from company ATS pages (bi-hourly)
- Sends Telegram alerts for new jobs
- Uses GitHub Actions for CI/CD

## Current Problem
Discovered companies are stored in n8n's internal staticData (SQLite on Fly.io volume).
If the volume is deleted, all discovered companies are LOST.
They are not version controlled or backed up.

## Solution: sources.json as Single Source of Truth

Make sources.json the ONLY place companies are stored:
1. Job discovery reads companies FROM sources.json (fetched from GitHub)
2. Company discovery APPENDS new companies TO sources.json (commits to GitHub)
3. Manual companies and discovered companies both live in sources.json
4. Everything is version controlled

---

## Repository Files

Key files to modify:
- `/sources.json` - Currently exists, needs new structure
- `/job-alerts-workflow.json` - Needs to read from GitHub instead of staticData
- `/company-discovery-workflow.json` - Needs to commit to GitHub instead of staticData
- `/.env.example` - Add GH_PAT variable

Other files (don't modify unless necessary):
- `/bot-commands-workflow.json`
- `/health-monitor-workflow.json`
- `/.github/workflows/deploy.yml`
- `/.github/workflows/sync-secrets.yml`
- `/fly.toml`
- `/SETUP.md`
- `/ARCHITECTURE.md`

---

## Implementation Details

### Step 1: Update sources.json Structure

Current structure:
```json
[
  { "ats": "greenhouse", "board": "hashicorp", ... },
  ...
]
```

New structure:
```json
{
  "version": "1.0",
  "lastUpdated": "2026-01-31T00:00:00Z",
  "manual": [
    { "ats": "greenhouse", "board": "hashicorp", "company": "HashiCorp", "enabled": true },
    { "ats": "lever", "board": "figma", "company": "Figma", "enabled": true }
  ],
  "discovered": [
    { "ats": "lever", "board": "modal", "company": "Modal", "discovered_at": "2026-01-31", "category": "AI Infrastructure", "enabled": true }
  ]
}
```

### Step 2: Modify job-alerts-workflow.json

In the "Load Source Configuration" node, change from reading staticData to:

```javascript
// Fetch sources.json from GitHub raw URL
const repoOwner = 'YOUR_GITHUB_USERNAME';
const repoName = 'n8n';
const branch = 'main';
const url = `https://raw.githubusercontent.com/${repoOwner}/${repoName}/${branch}/sources.json`;

// Or use environment variable for the URL
const sourcesUrl = $env.SOURCES_JSON_URL || url;

// Fetch and parse using n8n's $http helper
const response = await this.helpers.httpRequest({
  method: 'GET',
  url: sourcesUrl,
  json: true
});

// Merge manual + discovered
const allSources = [...response.manual, ...response.discovered];
const enabledSources = allSources.filter(s => s.enabled !== false);
```

### Step 3: Modify company-discovery-workflow.json

After the "Deduplicate & Store" node, add nodes to:

1. **Fetch current sources.json from GitHub API**
```javascript
// GET /repos/{owner}/{repo}/contents/sources.json
// Returns file content (base64) and sha (needed for update)
const response = await this.helpers.httpRequest({
  method: 'GET',
  url: 'https://api.github.com/repos/OWNER/REPO/contents/sources.json',
  headers: {
    'Authorization': `Bearer ${$env.GH_PAT}`,
    'Accept': 'application/vnd.github.v3+json'
  },
  json: true
});
const currentSha = response.sha;
const currentContent = JSON.parse(Buffer.from(response.content, 'base64').toString());
```

2. **Append new companies to discovered array**
```javascript
currentContent.discovered.push(...newCompanies);
currentContent.lastUpdated = new Date().toISOString();
```

3. **Commit updated file via GitHub API**
```javascript
await this.helpers.httpRequest({
  method: 'PUT',
  url: 'https://api.github.com/repos/OWNER/REPO/contents/sources.json',
  headers: {
    'Authorization': `Bearer ${$env.GH_PAT}`,
    'Accept': 'application/vnd.github.v3+json'
  },
  body: {
    message: 'chore: add discovered companies',
    content: Buffer.from(JSON.stringify(currentContent, null, 2)).toString('base64'),
    sha: currentSha
  },
  json: true
});
```

### Step 4: Add GitHub PAT Secret

Need a GitHub Personal Access Token:
1. GitHub → Settings → Developer Settings → Personal Access Tokens → Fine-grained tokens
2. Create token with:
   - Repository access: Only select your n8n repo
   - Permissions: Contents (Read and Write)
3. Add to Fly.io: `fly secrets set GH_PAT="ghp_xxxx"`
4. Add to GitHub Actions secrets: GH_PAT

### Step 5: Update .env.example

Add:
```bash
# GitHub Personal Access Token (for committing discovered companies)
GH_PAT=ghp_your_personal_access_token

# GitHub repo info for sources.json
GITHUB_REPO_OWNER=your-username
GITHUB_REPO_NAME=n8n

# Sources JSON URL (optional, for reading - no auth needed)
SOURCES_JSON_URL=https://raw.githubusercontent.com/USERNAME/n8n/main/sources.json
```

---

## GitHub API Reference

### Get file content:
```
GET https://api.github.com/repos/{owner}/{repo}/contents/sources.json
Headers: Authorization: Bearer {token}

Response includes:
- content: base64 encoded file content
- sha: required for updating the file
```

### Update file:
```
PUT https://api.github.com/repos/{owner}/{repo}/contents/sources.json
Headers:
  Authorization: Bearer {token}
  Content-Type: application/json
Body: {
  "message": "chore: add discovered companies",
  "content": "{base64 encoded new content}",
  "sha": "{sha from GET response}"
}
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        sources.json                              │
│                      (GitHub - main branch)                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ { "manual": [...], "discovered": [...] }                │    │
│  └─────────────────────────────────────────────────────────┘    │
│            │                               ▲                     │
│            │ (fetch raw URL)               │ (commit via API)   │
│            │ (no auth needed)              │ (needs GH_PAT)     │
│            ▼                               │                     │
│  ┌──────────────────┐           ┌──────────────────┐            │
│  │ Job Discovery    │           │ Company Discovery │            │
│  │ (every 2 hours)  │           │ (weekly)          │            │
│  │ READS sources    │           │ WRITES sources    │            │
│  └──────────────────┘           └──────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Verification Steps

1. After implementation, manually run Company Discovery workflow
2. Check GitHub - sources.json should have new entries in "discovered" array
3. Run Job Discovery - should scrape from both manual and discovered companies
4. Check git history - should see commit from n8n
5. Delete Fly.io volume and redeploy - companies should still be there (from GitHub)

---

## Important Notes

- Keep existing staticData for other things (seen job hashes, API usage tracking)
- Only move COMPANY LIST to sources.json
- Use GitHub raw URL for reading (no auth needed, faster, cached)
- Use GitHub API for writing (needs GH_PAT)
- Handle rate limits (GitHub API: 5000/hour with token)
- Raw URL may be cached for ~5 minutes by GitHub CDN

## Don't Break

- Existing job scraping functionality
- Deduplication of jobs (seenJobHashes in staticData - keep this)
- Telegram notifications
- Health monitoring
- Kill switches
- Filter versioning

---

## New Secrets Required

| Secret | Where to Add | Description |
|--------|--------------|-------------|
| `GH_PAT` | Fly.io + GitHub Actions | Personal Access Token with repo write access |
| `GITHUB_REPO_OWNER` | Fly.io (optional) | Your GitHub username |
| `GITHUB_REPO_NAME` | Fly.io (optional) | Repository name (n8n) |
