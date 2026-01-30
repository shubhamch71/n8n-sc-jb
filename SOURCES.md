# Job Sources Guide

This guide explains how to discover and add new job sources to the workflow without modifying any workflow nodes.

## Architecture Overview

The workflow uses a **source-agnostic design**:

1. **Source Configuration** - All sources are defined in the `Load Source Configuration` node as a data array
2. **Generic Handlers** - One HTTP handler per ATS type, URLs built dynamically from config
3. **Dynamic Routing** - Switch node routes each source to the correct handler based on `ats` type
4. **Normalized Output** - All handlers emit standardized job objects

**To add a new source: edit the configuration data only. No workflow node changes required.**

## Source Entry Schema

```javascript
{
  ats: 'greenhouse',       // Required: ATS type (determines handler)
  board: 'company-slug',   // Required: Identifier in ATS URL (or 'tag' for RemoteOK)
  company: 'Display Name', // Required: Human-readable name
  enabled: true,           // Optional: Toggle without removing (default: true)
  notes: 'Context'         // Optional: For your reference
}
```

## Supported ATS Types

### Greenhouse

**URL Pattern:** `https://boards-api.greenhouse.io/v1/boards/{board}/jobs`

**Finding the board name:**
1. Go to company careers page
2. Look for URL like `boards.greenhouse.io/company` or `jobs.greenhouse.io/company`
3. The path segment is the board name

**Test command:**
```bash
curl -s "https://boards-api.greenhouse.io/v1/boards/BOARD_NAME/jobs" | jq '.jobs | length'
```

**Example companies:**
| Company | Board Name |
|---------|------------|
| HashiCorp | hashicorp |
| GitLab | gitlab |
| Cloudflare | cloudflare |
| Datadog | datadog |
| Stripe | stripe |
| MongoDB | mongodb |
| Elastic | elastic |
| Grafana Labs | grafana |
| CockroachDB | cockroachlabs |
| Databricks | databricks |
| Confluent | confluent |
| PagerDuty | pagerduty |
| Snowflake | snowflake |
| Coinbase | coinbase |
| Airbnb | airbnb |
| Dropbox | dropbox |
| Plaid | plaid |
| Segment | segment |
| CircleCI | circleci |
| New Relic | newrelic |
| Splunk | splunk |
| Okta | okta |
| DigitalOcean | digitalocean |
| Fastly | fastly |

---

### Lever

**URL Pattern:** `https://api.lever.co/v0/postings/{board}?mode=json`

**Finding the board name:**
1. Go to `jobs.lever.co/company`
2. The path segment is the board name

**Test command:**
```bash
curl -s "https://api.lever.co/v0/postings/BOARD_NAME?mode=json" | jq 'length'
```

**Example companies:**
| Company | Board Name |
|---------|------------|
| Twilio | twilio |
| Figma | figma |
| Netflix | netflix |
| Discord | discord |
| Notion | notion |
| Vercel | vercel |
| Supabase | supabase |
| Netlify | netlify |
| Render | render |
| PostHog | posthog |

---

### Ashby

**URL Pattern:** `https://api.ashbyhq.com/posting-api/job-board/{board}`

**Finding the board name:**
1. Go to `jobs.ashbyhq.com/company`
2. The path segment is the board name

**Test command:**
```bash
curl -s "https://api.ashbyhq.com/posting-api/job-board/BOARD_NAME" | jq '.jobs | length'
```

**Example companies:**
| Company | Board Name |
|---------|------------|
| Ramp | ramp |
| Plaid | plaid |
| Linear | linear |

---

### SmartRecruiters

**URL Pattern:** `https://api.smartrecruiters.com/v1/companies/{board}/postings`

**Finding the board name:**
1. Go to `jobs.smartrecruiters.com/Company`
2. The company name in URL is the board (case-sensitive)

**Test command:**
```bash
curl -s "https://api.smartrecruiters.com/v1/companies/BOARD_NAME/postings" | jq '.content | length'
```

**Example companies:**
| Company | Board Name |
|---------|------------|
| Visa | Visa |
| Bosch | BOSCH |
| McDonald's | McDonalds |

---

### Workable

**URL Pattern:** `https://apply.workable.com/api/v1/widget/accounts/{board}`

**Finding the board name:**
1. Go to `apply.workable.com/company`
2. The path segment is the board name

**Test command:**
```bash
curl -s "https://apply.workable.com/api/v1/widget/accounts/BOARD_NAME" | jq '.jobs | length'
```

**Example companies:**
| Company | Board Name |
|---------|------------|
| Deel | deel |

---

### RemoteOK

**URL Pattern:** `https://remoteok.com/api?tag={tag}`

**Note:** Use `tag` instead of `board` in the config.

**Test command:**
```bash
curl -s "https://remoteok.com/api?tag=TAG_NAME" | jq 'length'
```

**Available tags:**
| Tag | Description |
|-----|-------------|
| devops | DevOps roles |
| cloud | Cloud engineering |
| sre | Site Reliability |
| kubernetes | Kubernetes roles |
| aws | AWS-focused roles |
| infrastructure | Infrastructure |
| platform | Platform engineering |

---

## Adding a New Source

### Step 1: Identify the ATS

Check the careers page URL:

| If URL contains... | ATS Type |
|-------------------|----------|
| `boards.greenhouse.io` or `jobs.greenhouse.io` | greenhouse |
| `jobs.lever.co` | lever |
| `jobs.ashbyhq.com` | ashby |
| `jobs.smartrecruiters.com` | smartrecruiters |
| `apply.workable.com` | workable |

### Step 2: Test the API

Use the test commands above to verify:
1. The endpoint is accessible
2. It returns job data
3. The board name is correct

### Step 3: Add to Configuration

Edit the **Load Source Configuration** node in n8n and add to the `staticData.sources` array:

```javascript
{ ats: 'greenhouse', board: 'new-company', company: 'New Company', enabled: true },
```

### Step 4: Save and Test

1. Save the workflow
2. Run manually to verify jobs are collected
3. Check execution logs for any errors

---

## Adding a New ATS Type

If you encounter an ATS not currently supported:

1. **Add switch case:** Edit "Route by ATS Type" node to add a new output
2. **Create HTTP handler:** Add HTTP Request node with URL pattern using `{{ $json.board }}`
3. **Create parser:** Add Code node to normalize response to standard job format
4. **Connect to collector:** Link parser output to "Collect Jobs" node

Standard job object:
```javascript
{
  job_title: "Job Title",
  company: "Company Name",
  location: "City, Country",
  job_url: "https://apply-link",
  source: "ATS Name",
  ats: "ats-type",
  board: "board-slug",
  description: "...",
  posted_at: "ISO date",
  job_id: "..."
}
```

---

## Unsupported ATS (Require Browser Automation)

These ATS types block API access and require Puppeteer/Playwright:

| ATS | Status | Notes |
|-----|--------|-------|
| Workday | Blocked | Session/cookie based |
| SAP SuccessFactors | Blocked | Complex auth |
| Oracle Taleo | Blocked | Session-based |
| Indeed | Rate Limited | May block IPs |
| LinkedIn | Blocked | Aggressive anti-scraping |
| iCIMS | Varies | Company-dependent |

For these, consider using dedicated scraping tools outside of n8n.

---

## Best Practices

1. **Test before adding** - Always verify API access with curl
2. **Start small** - Add 5-10 sources, monitor, then expand
3. **Use enabled flag** - Disable problematic sources without removing
4. **Monitor logs** - Check n8n execution logs for failures
5. **Respect rate limits** - Don't add too many sources from same domain
6. **Keep notes** - Document why sources are added/disabled
