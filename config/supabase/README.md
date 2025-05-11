# Supabase Schema for Job Automation System

This directory contains the optimized database schema for the job automation system, designed specifically for Supabase's free tier with a 500MB storage limit.

## Schema Overview

The database is designed to efficiently store and query job listings while minimizing storage usage through compression and JSONB storage:

### Tables

1. **Companies**
   - Simple table to store company information
   - Estimated size: ~10KB per company
   - Contains basic fields: id, name, domain, metadata

2. **Jobs**
   - Core table for job listings
   - Uses compressed description text (saves ~60% space)
   - Estimated size: ~5KB per job
   - Contains Canadian PR-specific fields (noc_code, pr_eligible)
   - Supports archiving via archived_at and is_active flags

3. **Applications**
   - Tracks job applications and status
   - Estimated size: ~1KB per application
   - Uses JSONB for flexible notes and analysis data

4. **Daily Stats**
   - Summary table for statistics and metrics
   - Updated daily to track performance and storage usage

### Indexes

```sql
CREATE INDEX idx_jobs_active ON jobs(is_active, scraped_at DESC);
CREATE INDEX idx_jobs_location ON jobs(location);
CREATE INDEX idx_jobs_title ON jobs USING gin(to_tsvector('english', title));
CREATE INDEX idx_applications_status ON applications(status);
CREATE INDEX idx_applications_score ON applications(match_score DESC);
```

### Storage Optimization Functions

The schema uses PostgreSQL's built-in compression functionality to reduce the storage size of job descriptions:

```sql
-- Compression function
CREATE OR REPLACE FUNCTION compress_text(input TEXT) 
RETURNS BYTEA AS $$
BEGIN
    RETURN compress(input::bytea);
END;
$$ LANGUAGE plpgsql;

-- Decompression function
CREATE OR REPLACE FUNCTION decompress_text(input BYTEA) 
RETURNS TEXT AS $$
BEGIN
    RETURN convert_from(decompress(input), 'UTF8');
END;
$$ LANGUAGE plpgsql;
```

### Maintenance Functions

```sql
-- Auto-archive old jobs
CREATE OR REPLACE FUNCTION archive_old_jobs() 
RETURNS void AS $$
BEGIN
    UPDATE jobs 
    SET archived_at = NOW(), is_active = false
    WHERE scraped_at < NOW() - INTERVAL '30 days' 
    AND is_active = true;
END;
$$ LANGUAGE plpgsql;

-- Database maintenance
CREATE OR REPLACE FUNCTION maintain_database() 
RETURNS void AS $$
BEGIN
    -- Archive old jobs
    PERFORM archive_old_jobs();
    
    -- Update statistics
    ANALYZE jobs;
    ANALYZE applications;
    
    -- Log current usage
    INSERT INTO daily_stats (date, metrics)
    VALUES (CURRENT_DATE, 
        jsonb_build_object(
            'storage_mb', pg_database_size(current_database()) / 1024 / 1024,
            'active_jobs', (SELECT COUNT(*) FROM jobs WHERE is_active = true)
        )
    )
    ON CONFLICT (date) DO UPDATE
    SET metrics = daily_stats.metrics || EXCLUDED.metrics;
END;
$$ LANGUAGE plpgsql;
```

## Storage Efficiency

This schema is designed to efficiently store 5,000-7,000 active jobs within the 500MB storage limit of Supabase's free tier:

- **Text Compression**: Job descriptions are compressed, saving ~60% of storage space
- **JSONB Fields**: Flexible fields use JSONB to avoid adding numerous columns
- **Archiving**: Old jobs are automatically archived after 30 days
- **Shared Companies**: Job listings reference companies to avoid duplication

## Usage

### Applying the Schema

Use the `apply-schema.js` script to create the schema in your Supabase project:

```bash
cd scripts
node apply-schema.js
```

### Monitoring Storage

Monitor storage usage with the `check-storage.js` script:

```bash
cd scripts
node check-storage.js
```

### Query Performance Testing

Test query performance with the `test-queries.js` script:

```bash
cd scripts
node test-queries.js
```

## Storage Monitoring

The schema includes a view to monitor storage usage:

```sql
CREATE VIEW storage_monitor AS
SELECT 
    pg_size_pretty(pg_database_size(current_database())) as database_size,
    pg_size_pretty(pg_total_relation_size('jobs')) as jobs_table_size,
    pg_size_pretty(pg_total_relation_size('applications')) as applications_table_size,
    COUNT(*) FILTER (WHERE is_active = true) as active_jobs,
    COUNT(*) FILTER (WHERE archived_at IS NOT NULL) as archived_jobs
FROM jobs;
```

## Integration with n8n

When working with this schema in n8n:

1. Use the `insert_job_with_compression` function to add jobs with compressed descriptions
2. Use the `get_job_with_description` function to retrieve jobs with decompressed descriptions
3. Set up a scheduled task to run the `maintain_database` function daily

## Best Practices

1. Always use batch inserts when adding multiple jobs
2. Select only needed fields in queries
3. Use the compression functions for large text fields
4. Regularly run the maintenance function to archive old jobs
5. Monitor storage usage to stay within the 500MB limit 