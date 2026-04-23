# Connecting Claude Code to Org62 (Salesforce CLI)

This guide walks you through setting up the Salesforce CLI so Claude can pull live data from Org62 — forecast dashboards, DSR reports, pipeline data, and SOQL queries.

## What You Get

Once connected, Claude can:
- Pull forecast pipeline dashboards (CW ACV, pipeline, SFRs, walk-up)
- Pull product-level ACV and pipeline data
- Pull DSR workload by cloud, SE owner, and product line
- Run SOQL queries against Org62
- Download reports for analysis
- Cross-reference deal data with your knowledge base
- Power the Monday business readout (automated weekly)

## Prerequisites

- Salesforce employee with Org62 access
- Homebrew installed (`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`)

## Setup Steps

### 1. Install the Salesforce CLI

```bash
brew install sf
```

Verify:
```bash
sf --version
```

### 2. Authenticate to Org62

```bash
sf org login web --alias org62 --instance-url https://org62.my.salesforce.com
```

This opens a browser window. Log in with your Salesforce credentials (Okta SSO). Once authenticated, the CLI stores your session locally.

### 3. Set as default org

```bash
sf config set target-org org62
```

### 4. Verify it works

```bash
sf org display --target-org org62
```

You should see your username, org ID, and instance URL.

### 5. Test a query

```bash
sf data query --query "SELECT Id, Name FROM User WHERE Email = 'your-email@salesforce.com'" --target-org org62
```

### 6. Tell Claude your dashboard IDs

Claude needs the IDs of the dashboards you want to monitor. To find a dashboard ID:

1. Open the dashboard in Org62 (Lightning)
2. Look at the URL: `https://org62.lightning.force.com/lightning/r/Dashboard/01Zxxxxxxxxxx/view`
3. The ID is the `01Zxxxxxxxxxx` part

Tell Claude: "My forecast dashboard ID is 01Zxxxxxxxxxx" — Claude will wire it into TOOLS.md.

Common dashboards to configure:
- **Forecast pipeline** — CW ACV, IN pipe, walk-up
- **Product forecast** — ACV by product line, pipeline by product
- **DSR workload** — DSRs by cloud, by SE owner, by product

## How Claude Uses Org62

**SOQL queries:**
```bash
sf data query --query "SELECT ..." --target-org org62 --json
```

**Dashboard data (Analytics API):**
```bash
sf api request rest "/services/data/v62.0/analytics/dashboards/DASHBOARD_ID" --target-org org62
```

**Reports:**
```bash
sf api request rest "/services/data/v62.0/analytics/reports/REPORT_ID" --target-org org62
```

## Session Expiration

Org62 sessions expire periodically. If Claude gets auth errors:

```bash
sf org login web --alias org62 --instance-url https://org62.my.salesforce.com
```

Re-authenticate and you're back.

## Privacy Notes

- Claude only reads data you have access to in Org62
- All data stays in your local project files
- Claude never modifies Org62 data — read only
