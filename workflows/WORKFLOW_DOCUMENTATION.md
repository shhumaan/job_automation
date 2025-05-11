# Job Automation System Workflow Documentation

## System Overview

This job automation system uses n8n to orchestrate the following processes:
1. Scraping job listings from various sources
2. Processing and deduplicating job data
3. Storing jobs in Supabase
4. Handling errors and monitoring performance

The system is optimized for Supabase's free tier with batch processing and efficient storage.

## Workflow Structure

### 1. Master Controller
**Purpose:** Orchestrates the entire job automation process
**Schedule:** Runs 3 times daily (6 AM, 2 PM, 9 PM)
**Workflow ID:** `${JOB_SCRAPER_WORKFLOW_ID}`

**Key Components:**
- Schedule trigger (6 AM, 2 PM, 9 PM)
- Execution preparation
- Sequential execution of other workflows
- Error handling
- Performance tracking

### 2. Job Scraper Template
**Purpose:** Template for scraping job listings from various sources
**Trigger:** Called by Master Controller
**Workflow ID:** `${JOB_SCRAPER_WORKFLOW_ID}`

**Key Components:**
- Job site configuration
- HTTP request with proper headers/cookies
- HTML parsing and data extraction
- Rate limiting and retry logic
- Data formatting for consistency

### 3. Data Processor
**Purpose:** Cleans, standardizes, and deduplicates job data
**Trigger:** Called by Master Controller after Job Scraper
**Workflow ID:** `${DATA_PROCESSOR_WORKFLOW_ID}`

**Key Components:**
- Job data cleaning and normalization
- Deduplication against existing jobs
- Batch processing for Supabase
- Data validation
- Database storage optimization

### 4. Error Handler
**Purpose:** Captures and processes errors
**Trigger:** Called when errors occur in any workflow
**Workflow ID:** `${ERROR_HANDLER_WORKFLOW_ID}`

**Key Components:**
- Error categorization
- Retry logic for recoverable errors
- Error logging in Supabase
- Notification system
- Recovery procedures

### 5. Performance Monitor
**Purpose:** Tracks execution metrics and Supabase usage
**Trigger:** Called by Master Controller after processing
**Workflow ID:** `${PERFORMANCE_MONITOR_WORKFLOW_ID}`

**Key Components:**
- Execution time tracking
- Job count metrics
- Supabase usage monitoring
- Free tier limit warnings
- Performance optimization suggestions

## Supabase Integration

The system uses Supabase for data storage with these optimizations:
1. Batch inserts to minimize API calls
2. Selective querying (only needed fields)
3. Regular cleanup of old data to stay within free tier limits
4. Connection pooling and retry strategies
5. RLS policies for security

## Usage Instructions

### Activating Workflows
1. Open n8n interface at http://localhost:5678
2. Navigate to the Workflows page
3. For each workflow, ensure it's activated (toggle switch in top-right)
4. Verify Supabase credentials are properly set in all nodes

### Workflow IDs
After importing workflows, update the `.env` file with the correct workflow IDs:
- `JOB_SCRAPER_WORKFLOW_ID` - ID of the Job Scraper Template workflow
- `DATA_PROCESSOR_WORKFLOW_ID` - ID of the Data Processor workflow 
- `ERROR_HANDLER_WORKFLOW_ID` - ID of the Error Handler workflow
- `PERFORMANCE_MONITOR_WORKFLOW_ID` - ID of the Performance Monitor workflow

### Testing the System
1. Run the Master Controller workflow manually first
2. Check Supabase for new records
3. Verify error logs and performance metrics
4. Adjust scheduling as needed

## Troubleshooting

### Common Issues
1. **Supabase connection errors** - Check API keys and URL in environment variables
2. **n8n workflow not activating** - Ensure proper authentication and workflow IDs
3. **Missing data** - Check extraction logic in Job Scraper Template
4. **Rate limiting** - Adjust timing in HTTP Request nodes

### Validation
Run the validation script to check the system:
```
cd scripts
./validate-setup.js
```

## Maintenance

### Regular Tasks
1. Monitor free tier usage in Supabase
2. Update job scraper configurations as websites change
3. Review error logs and performance metrics
4. Backup workflow configurations

### Supabase Optimization
1. Run cleanup functions regularly to stay within limits
2. Archive old data if needed
3. Monitor API usage and adjust batch sizes

## Security Considerations

1. API keys are stored in environment variables
2. Supabase RLS policies restrict access to data
3. Encryption for sensitive data in transit and at rest 