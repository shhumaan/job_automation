# n8n Workflow for Daily Job Collection

This directory contains the n8n workflow for automating daily job collection from Adzuna API.

## Files

- `daily-job-collection.json` - The workflow definition file that can be imported into n8n
- `daily-job-collection-guide.md` - Detailed step-by-step guide for setting up the workflow
- `README.md` - This file

## Quick Start

1. Make sure n8n is running (`docker-compose up -d`)
2. Open n8n at http://localhost:5678
3. Import the workflow from `daily-job-collection.json`
4. Configure the Supabase and Gmail credentials
5. Test the workflow by clicking "Execute Workflow"
6. If successful, activate the workflow for daily execution at 6 AM

## Testing Outside n8n

You can test the core functionality without n8n by running:

```bash
node job-search/test/test-n8n-integration.js
```

This script simulates the workflow logic and displays sample results.

## Database Requirements

The Supabase database should have a `jobs` table with these fields:

- `id` (primary key, text)
- `title` (text)
- `company` (text)
- `location` (text)
- `url` (text)
- `description` (text)
- `salary_min` (numeric, nullable)
- `salary_max` (numeric, nullable)
- `created` (timestamp)
- `category` (text)
- `contract_type` (text)
- `contract_time` (text)
- `scraped_at` (timestamp)
- `source` (text)
- `match_score` (numeric, nullable)
- `is_active` (boolean)

## Workflow Logic

1. **Cron Node**: Scheduled trigger at 6 AM daily
2. **Code Node**: Fetches 40 jobs from Adzuna API using multiple job titles
3. **Function Node**: Deduplicates jobs by ID
4. **Supabase Node**: Saves jobs to database
5. **Gmail Node**: Sends daily summary email

## Troubleshooting

- If jobs aren't being collected, verify the Adzuna API credentials and paths
- Check that you have n8n credentials configured for Supabase and Gmail
- Ensure n8n is running and can access the internet
- Verify that the workflow is activated

## Maintenance

- Update `job-titles.js` to change the job search targets
- Check the API rate limits in `adzuna-client.js` if frequent calls are needed
- Monitor email notifications to ensure the workflow is running daily 