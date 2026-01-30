# Job Sources Configuration Guide

This document explains how to add new job sources to the workflow.

## Currently Supported ATS Types

### Greenhouse (JSON API)

**API Pattern:**
```
https://boards-api.greenhouse.io/v1/boards/{company-board-name}/jobs
```

**How to find the board name:**
1. Go to `https://boards.greenhouse.io/{company-name}`
2. The company name in the URL is the board name

**Popular Greenhouse Companies:**

| Company | Board Name | URL |
|---------|-----------|-----|
| HashiCorp | hashicorp | boards.greenhouse.io/hashicorp |
| GitLab | gitlab | boards.greenhouse.io/gitlab |
| Cloudflare | cloudflare | boards.greenhouse.io/cloudflare |
| Datadog | datadog | boards.greenhouse.io/datadog |
| MongoDB | mongodb | boards.greenhouse.io/mongodb |
| Elastic | elastic | boards.greenhouse.io/elastic |
| CockroachDB | cockroachlabs | boards.greenhouse.io/cockroachlabs |
| Stripe | stripe | boards.greenhouse.io/stripe |
| Airbnb | airbnb | boards.greenhouse.io/airbnb |
| Dropbox | dropbox | boards.greenhouse.io/dropbox |
| Coinbase | coinbase | boards.greenhouse.io/coinbase |
| Plaid | plaid | boards.greenhouse.io/plaid |
| Snowflake | snowflake | boards.greenhouse.io/snowflake |
| Databricks | databricks | boards.greenhouse.io/databricks |
| Confluent | confluent | boards.greenhouse.io/confluent |
| Grafana Labs | grafana | boards.greenhouse.io/grafana |
| PagerDuty | pagerduty | boards.greenhouse.io/pagerduty |
| Samsara | samsara | boards.greenhouse.io/samsara |
| Segment | segment | boards.greenhouse.io/segment |
| Amplitude | amplitude | boards.greenhouse.io/amplitude |
| CircleCI | circleci | boards.greenhouse.io/circleci |
| LaunchDarkly | launchdarkly | boards.greenhouse.io/launchdarkly |
| New Relic | newrelic | boards.greenhouse.io/newrelic |
| Splunk | splunk | boards.greenhouse.io/splunk |
| Sumo Logic | sumologic | boards.greenhouse.io/sumologic |
| Okta | okta | boards.greenhouse.io/okta |
| Auth0 | auth0 | boards.greenhouse.io/auth0 |
| 1Password | 1password | boards.greenhouse.io/1password |
| Akamai | akamai | boards.greenhouse.io/akamai |
| DigitalOcean | digitalocean | boards.greenhouse.io/digitalocean |
| Linode | linode | boards.greenhouse.io/linode |
| Vultr | vultr | boards.greenhouse.io/vultr |
| Fastly | fastly | boards.greenhouse.io/fastly |

### Lever (JSON API)

**API Pattern:**
```
https://api.lever.co/v0/postings/{company-slug}?mode=json
```

**How to find the company slug:**
1. Go to `https://jobs.lever.co/{company-slug}`
2. The slug is in the URL

**Popular Lever Companies:**

| Company | Slug | URL |
|---------|------|-----|
| Twilio | twilio | jobs.lever.co/twilio |
| Figma | figma | jobs.lever.co/figma |
| Netflix | netflix | jobs.lever.co/netflix |
| Discord | discord | jobs.lever.co/discord |
| Notion | notion | jobs.lever.co/notion |
| Linear | linear | jobs.lever.co/linear |
| Vercel | vercel | jobs.lever.co/vercel |
| Supabase | supabase | jobs.lever.co/supabase |
| Netlify | netlify | jobs.lever.co/netlify |
| Render | render | jobs.lever.co/render |
| Railway | railway | jobs.lever.co/railway |
| Fly.io | fly | jobs.lever.co/fly |
| PostHog | posthog | jobs.lever.co/posthog |
| Segment | segment | jobs.lever.co/segment |

### RemoteOK (JSON API)

**API Pattern:**
```
https://remoteok.com/api?tag={tag}
```

**Popular Tags:**
- devops
- cloud
- sre
- kubernetes
- aws
- infrastructure
- platform
- mlops

### Ashby (JSON API)

**API Pattern:**
```
https://api.ashbyhq.com/posting-api/job-board/{company}
```

**Popular Ashby Companies:**
- ramp
- notion
- plaid

## Adding Sources to the Workflow

### Option 1: Simple Workflow (job-alerts-workflow.json)

Add a new HTTP Request node:

1. Copy an existing Greenhouse/Lever node
2. Change the URL to the new company
3. Connect it to the "Normalize All Jobs" node
4. The normalizer handles standard Greenhouse/Lever formats

### Option 2: Extended Workflow (job-alerts-workflow-extended.json)

Edit the "Initialize Sources" code node:

```javascript
const sources = [
  // Add new Greenhouse company
  { type: 'greenhouse', company: 'new-company', name: 'New Company' },

  // Add new Lever company
  { type: 'lever', company: 'new-company', name: 'New Company' },

  // Add new RemoteOK tag
  { type: 'remoteok', tag: 'new-tag', name: 'RemoteOK New Tag' },

  // ... existing sources
];
```

## Testing a New Source

Before adding to the workflow, test the API:

```bash
# Greenhouse
curl -s "https://boards-api.greenhouse.io/v1/boards/COMPANY/jobs" | jq '.jobs | length'

# Lever
curl -s "https://api.lever.co/v0/postings/COMPANY?mode=json" | jq 'length'

# RemoteOK
curl -s "https://remoteok.com/api?tag=TAG" | jq 'length'
```

## Unsupported ATS Types

These require custom parsing or may block automated access:

| ATS | Status | Notes |
|-----|--------|-------|
| Workday | Blocked | Requires session/cookies |
| SAP SuccessFactors | Blocked | Complex auth |
| Oracle Taleo | Blocked | Session-based |
| Indeed | Rate Limited | May block IPs |
| LinkedIn | Blocked | Requires auth, aggressive blocking |
| iCIMS | Varies | Some have JSON, some don't |
| SmartRecruiters | Partial | Some companies expose JSON |
| Jobvite | Partial | Company-dependent |

## Best Practices

1. **Rate Limiting**: Don't add too many sources; aim for 20-30 max
2. **Test First**: Always test the API endpoint before adding
3. **Monitor**: Check execution logs for failures
4. **Rotate**: If a source consistently fails, remove it
5. **Respect robots.txt**: Some companies may block scraping
