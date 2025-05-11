# Daily 40 Jobs Collection - n8n Workflow Setup Guide

This guide provides step-by-step instructions for setting up an n8n workflow to automate daily job collection using the Adzuna API client.

## Prerequisites

- n8n running at http://localhost:5678
- Supabase database configured with a `jobs` table
- Gmail account for sending email summaries

## Workflow Overview

The workflow consists of 5 nodes:
1. **Cron** - Scheduled trigger that runs daily at 6 AM
2. **Get 40 Jobs** - Code node that retrieves 40 jobs from Adzuna
3. **Deduplicate Jobs** - Function node that removes duplicate jobs
4. **Save to Supabase** - Saves the jobs to a database
5. **Gmail** - Sends a daily summary email

## Step-by-Step Setup

### 1. Create a New Workflow

1. Open n8n (http://localhost:5678)
2. Click on "Workflows" in the sidebar
3. Click "+ Create new" and select "Blank workflow"
4. Name the workflow "Daily 40 Jobs Collection"

### 2. Add Cron Node

1. Click the "+" button in the editor
2. Search for "Cron" and add it to the workflow
3. Configure with these settings:
   - Mode: Every Day
   - Hour: 6
   - Minute: 0
   - Timezone: America/Toronto

### 3. Add Code Node (Get 40 Jobs)

1. Click the "+" button after the Cron node
2. Search for "Code" and add it to the workflow
3. Name it "Get 40 Jobs"
4. Set the language to "JavaScript"
5. Paste this code:

```javascript
const AdzunaClient = require('/Users/anshuman/job_automation/job-search/adzuna-client');
const jobTitles = require('/Users/anshuman/job_automation/job-search/job-titles');

const client = new AdzunaClient();
const jobs = await client.getDailyJobs(jobTitles, 'Ontario', 40);

// Add metadata
const enrichedJobs = jobs.map(job => ({
  ...job,
  scraped_at: new Date().toISOString(),
  source: 'adzuna',
  match_score: null, // Will be calculated in next phase
  is_active: true
}));

return enrichedJobs.map(job => ({ json: job }));
```

### 4. Add Function Node (Deduplicate Jobs)

1. Click the "+" button after the Code node
2. Search for "Function" and add it to the workflow
3. Name it "Deduplicate Jobs"
4. Paste this code:

```javascript
const items = $input.all();
const uniqueJobs = {};

// Deduplicate by job ID
items.forEach(item => {
  const job = item.json;
  uniqueJobs[job.id] = job;
});

return Object.values(uniqueJobs).map(job => ({ json: job }));
```

### 5. Add Supabase Node

1. Click the "+" button after the Function node
2. Search for "Supabase" and add it to the workflow
3. Name it "Save to Supabase"
4. Set up Supabase credentials if not already set
5. Configure with these settings:
   - Operation: Upsert
   - Table: jobs
   - Columns: `={{ Object.keys($json) }}`
   - Conflict columns: id
   - Update existing: true

### 6. Add Gmail Node

1. Click the "+" button after the Supabase node
2. Search for "Gmail" and add it to the workflow
3. Name it "Send Email Summary"
4. Set up Gmail credentials if not already set
5. Configure with these settings:
   - From: job-automation@example.com (or use default account)
   - To: Your email address (or use `{{ $env.NOTIFICATION_EMAIL }}`)
   - Subject: `Daily Jobs Report - {{ $now.format("YYYY-MM-DD") }}`
   - Message: 
     ```
     Daily Jobs Report

     Date: {{ $now.format("YYYY-MM-DD") }}
     Time: {{ $now.format("HH:mm:ss") }}

     Jobs Collected: {{ $node["Deduplicate Jobs"].json.length }}

     Job Categories:
     {% for job in $node["Deduplicate Jobs"].json %}
     - {{ job.title }} at {{ job.company }}
     {% endfor %}

     The jobs have been saved to the database.
     ```

### 7. Connect the Nodes

1. Connect the nodes in the following order:
   - Cron → Get 40 Jobs
   - Get 40 Jobs → Deduplicate Jobs
   - Deduplicate Jobs → Save to Supabase
   - Save to Supabase → Send Email Summary

### 8. Test the Workflow

1. Click the "Execute Workflow" button (play icon)
2. Check the execution results for each node
3. Verify the jobs are saved to Supabase
4. Check your email for the summary

### 9. Activate the Workflow

1. Toggle the "Active" switch to activate the workflow
2. The workflow will now run automatically every day at 6 AM

## Alternative: Import Workflow

Alternatively, you can import the entire workflow from the provided JSON file:

1. Go to n8n
2. Click on "Workflows" in the sidebar
3. Click "Import from File"
4. Select the `daily-job-collection.json` file
5. Configure credentials for Supabase and Gmail
6. Activate the workflow

## Troubleshooting

- If the Code node fails, ensure the paths to the Adzuna client and job titles files are correct
- Check that the Supabase table has the correct schema to match the job data
- Verify that the Gmail credentials are configured correctly
- Check the n8n logs for detailed error messages

## Validation Checklist

- [x] Workflow created
- [x] Scheduled for 6 AM daily
- [x] Gets exactly 40 jobs
- [x] Saves to Supabase
- [x] Sends email summary 