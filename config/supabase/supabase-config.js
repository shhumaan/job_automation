/**
 * Supabase Configuration for Job Automation Project
 * 
 * This file contains settings optimized for Supabase free tier:
 * - Max 500MB database size
 * - 2 simultaneous connections
 * - Limited storage (1GB)
 * - Rate limits
 */

module.exports = {
    // Database Schema Configuration
    schema: {
        // Tables structure with conservative column types to save space
        tables: {
            jobs: {
                id: 'uuid primary key default gen_random_uuid()',
                title: 'text not null',
                company: 'text not null',
                location: 'text',
                description: 'text',
                salary: 'text',
                apply_link: 'text',
                source: 'text',
                posted: 'timestamp with time zone default now()',
                processed: 'timestamp with time zone default now()',
                tags: 'jsonb',
                meta_data: 'jsonb'
            },
            error_logs: {
                id: 'uuid primary key default gen_random_uuid()',
                timestamp: 'timestamp with time zone default now()',
                workflow_name: 'text',
                execution_id: 'text',
                error_message: 'text',
                error_trace: 'text',
                severity: 'text',
                input_data: 'jsonb'
            },
            performance_metrics: {
                id: 'uuid primary key default gen_random_uuid()',
                execution_id: 'text',
                timestamp: 'timestamp with time zone default now()',
                schedule: 'text',
                duration_ms: 'integer',
                job_count: 'integer',
                start_time: 'timestamp with time zone',
                end_time: 'timestamp with time zone',
                source: 'text',
                success: 'boolean default true'
            }
        },

        // Indexes for optimal performance
        indexes: {
            jobs_title_company_idx: 'CREATE INDEX IF NOT EXISTS jobs_title_company_idx ON jobs (title, company)',
            jobs_posted_idx: 'CREATE INDEX IF NOT EXISTS jobs_posted_idx ON jobs (posted)',
            performance_metrics_timestamp_idx: 'CREATE INDEX IF NOT EXISTS performance_metrics_timestamp_idx ON performance_metrics (timestamp)'
        },

        // Row level security policies
        rls: {
            jobs_read: 'CREATE POLICY "Anyone can read jobs" ON jobs FOR SELECT USING (true)',
            jobs_insert: 'CREATE POLICY "Service role can insert jobs" ON jobs FOR INSERT WITH CHECK (auth.role() = \'service_role\')',
            jobs_update: 'CREATE POLICY "Service role can update jobs" ON jobs FOR UPDATE USING (auth.role() = \'service_role\')',
            error_logs_policies: 'CREATE POLICY "Only service role access error logs" ON error_logs USING (auth.role() = \'service_role\')',
            performance_metrics_policies: 'CREATE POLICY "Only service role access metrics" ON performance_metrics USING (auth.role() = \'service_role\')'
        }
    },

    // Functions to help manage database size on free tier
    functions: {
        // Cleanup function to remove old data
        cleanup_old_jobs: `
      CREATE OR REPLACE FUNCTION cleanup_old_jobs() RETURNS void AS $$
      BEGIN
        DELETE FROM jobs WHERE posted < NOW() - INTERVAL '30 days';
      END;
      $$ LANGUAGE plpgsql;
    `,
        // Cleanup function for error logs
        cleanup_old_logs: `
      CREATE OR REPLACE FUNCTION cleanup_old_logs() RETURNS void AS $$
      BEGIN
        DELETE FROM error_logs WHERE timestamp < NOW() - INTERVAL '7 days';
        DELETE FROM performance_metrics WHERE timestamp < NOW() - INTERVAL '14 days';
      END;
      $$ LANGUAGE plpgsql;
    `
    },

    // Connection settings optimized for free tier
    connection: {
        // Retry strategy with exponential backoff
        maxRetries: 5,
        retryDelay: 1000, // Start with 1 second
        retryBackoff: 2, // Double the delay each time
        connectionTimeout: 15000, // 15 seconds
        // Batch inserts to reduce API calls
        batchSize: 10,
        // Rate limiting settings
        rateLimit: {
            max: 1000, // Max requests per hour (free tier)
            timeWindow: 3600000, // 1 hour in milliseconds
        }
    }
};