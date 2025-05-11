# Updating n8n Workflows for Optimized Supabase Schema

## Overview

This guide explains how to update your n8n workflows to use the optimized, storage-efficient Supabase schema. The key changes include using compression functions for job descriptions and properly handling batch operations.

## Required Changes

### 1. Job Scraper Template

Update the Supabase node to use the `insert_job_with_compression` function:

1. Open your Job Scraper Template workflow
2. Navigate to the final Supabase node
3. Change the operation from basic "Insert" to "Run Function"
4. Select the `insert_job_with_compression` function
5. Map your parameters:

```javascript
// Example function item mapping
return {
  json: {
    // Required parameters for insert_job_with_compression
    p_external_id: item.job_id || item.id || `job_${Date.now()}`,
    p_title: item.title,
    p_company_name: item.company,
    p_location: item.location || "Unknown",
    p_remote_type: item.remote_type || "onsite",
    p_description: item.description || "",
    p_requirements: item.requirements || {},
    p_noc_code: item.noc_code || null,
    p_posted_date: item.posted_date || new Date().toISOString().split('T')[0],
    p_source: item.source || "unknown",
    p_url: item.url || item.apply_link || "",
    p_salary_info: item.salary_info || {}
  }
};
```

### 2. Data Processor

For the Data Processor workflow:

1. Update the Supabase query for deduplication to use the indexed fields
2. Update batch inserts to use the compression function

```javascript
// Example batch insert using the compression function
const jobs = $input.first().json.newJobs;
const batchSize = 10; // Adjust for optimal performance
const result = [];

// Process jobs in batches
for (let i = 0; i < jobs.length; i += batchSize) {
  const batch = jobs.slice(i, i + batchSize);
  
  // Map each job to function parameters
  const items = batch.map(job => ({
    p_external_id: job.external_id || `job_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
    p_title: job.title,
    p_company_name: job.company,
    p_location: job.location,
    p_remote_type: job.remote_type || "onsite",
    p_description: job.description,
    p_requirements: job.requirements || {},
    p_noc_code: job.noc_code || null,
    p_posted_date: job.posted_date,
    p_source: job.source,
    p_url: job.url,
    p_salary_info: job.salary_info || {}
  }));
  
  // Call your Supabase function (implement in n8n HTTP Request or Supabase node)
  // result.push(await callSupabaseFunction(items));
}

return { json: { result } };
```

### 3. Error Handler

When logging errors to Supabase:

1. Use batch inserts when possible
2. Keep error messages concise (no need to compress these)
3. Use the JSONB `error_data` field for detailed error information

### 4. Performance Monitor

Add additional monitoring for Supabase free tier limits:

1. Add a daily check to call the storage_monitor view
2. Log the results in daily_stats
3. Set up alerts for storage approaching limits

## Sample Function Calls

### Check Storage Usage

```javascript
// Example code to check storage usage in n8n
const { data } = await $node["Supabase"].runFunction({
  function: "exec_sql_with_results",
  parameters: {
    sql: "SELECT * FROM storage_monitor"
  }
});

// Check if approaching limits
const dbSize = data[0].database_size;
const matches = dbSize.match(/(\d+\.?\d*)\s*([KMG]B)/);
if (matches) {
  const size = parseFloat(matches[1]);
  const unit = matches[2];
  
  // Convert to MB for comparison
  let sizeInMB = size;
  if (unit === 'KB') sizeInMB = size / 1024;
  if (unit === 'GB') sizeInMB = size * 1024;
  
  // Alert if over 400MB (80% of 500MB limit)
  if (sizeInMB > 400) {
    // Trigger alert workflow
  }
}

return { json: { storageData: data[0] } };
```

### Run Maintenance Function

Add a scheduled task to run the maintenance function:

```javascript
// Call the database maintenance function daily
const { data, error } = await $node["Supabase"].runFunction({
  function: "maintain_database",
  parameters: {}
});

if (error) {
  console.log("Error running maintenance:", error);
  return { json: { success: false, error } };
}

return { json: { success: true, message: "Maintenance completed" } };
```

## Additional Optimizations

1. **Retrieve Jobs with Description**:
   ```sql
   SELECT * FROM get_job_with_description('job-uuid-here')
   ```

2. **Archive Old Jobs Manually**:
   ```sql
   SELECT archive_old_jobs()
   ```

3. **Test Compression**:
   ```sql
   SELECT * FROM test_compression('Text to compress')
   ```

## Best Practices

1. Always use batch operations (10-20 records at a time)
2. Only select the fields you need in queries
3. Use the compression functions for large text fields
4. Run the maintenance function daily
5. Monitor storage usage regularly
6. Archive data as needed to stay within free tier limits 