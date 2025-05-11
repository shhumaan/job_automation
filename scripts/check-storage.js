#!/usr/bin/env node

/**
 * Supabase Storage Usage Report
 * 
 * This script checks and reports on Supabase database storage usage
 * to help monitor free tier limits (500MB).
 */

require('dotenv').config({ path: '../.env' });
const { createClient } = require('@supabase/supabase-js');

// Colors for console output
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m',
    magenta: '\x1b[35m'
};

// Main function to check storage
async function checkStorage() {
    console.log(`\n${colors.cyan}=== Supabase Storage Usage Report ====${colors.reset}\n`);

    // Get Supabase credentials
    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_API_KEY;

    if (!supabaseUrl || !supabaseKey) {
        console.error(`${colors.red}Error: SUPABASE_URL and SUPABASE_API_KEY must be set in .env file${colors.reset}`);
        process.exit(1);
    }

    // Create Supabase client
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Check if storage_monitor view exists
    try {
        const { data: monitorData, error: monitorError } = await supabase
            .from('storage_monitor')
            .select('*')
            .limit(1);

        if (monitorError) {
            console.log(`${colors.yellow}⚠ storage_monitor view is not available: ${monitorError.message}${colors.reset}`);
            console.log(`${colors.yellow}⚠ Using manual queries instead...${colors.reset}`);
            await checkStorageManually(supabase);
        } else {
            console.log(`${colors.green}✓ Using storage_monitor view${colors.reset}`);
            console.log(`\n${colors.blue}=== Current Storage Usage ===${colors.reset}`);

            const monitor = monitorData[0];
            console.log(`${colors.cyan}Database Size: ${monitor.database_size}${colors.reset}`);
            console.log(`${colors.cyan}Jobs Table Size: ${monitor.jobs_table_size}${colors.reset}`);
            console.log(`${colors.cyan}Applications Table Size: ${monitor.applications_table_size}${colors.reset}`);
            console.log(`${colors.cyan}Active Jobs: ${monitor.active_jobs}${colors.reset}`);
            console.log(`${colors.cyan}Archived Jobs: ${monitor.archived_jobs}${colors.reset}`);
        }
    } catch (error) {
        console.error(`${colors.red}Error checking storage_monitor: ${error.message}${colors.reset}`);
        await checkStorageManually(supabase);
    }

    // Get daily statistics
    try {
        const { data: statsData, error: statsError } = await supabase
            .from('daily_stats')
            .select('*')
            .order('date', { ascending: false })
            .limit(7);

        if (statsError) {
            console.log(`${colors.yellow}⚠ Could not retrieve daily statistics: ${statsError.message}${colors.reset}`);
        } else if (statsData && statsData.length > 0) {
            console.log(`\n${colors.blue}=== Recent Daily Statistics ===${colors.reset}`);

            statsData.forEach(stat => {
                console.log(`\n${colors.magenta}${stat.date}:${colors.reset}`);
                console.log(`  Jobs Scraped: ${stat.jobs_scraped}`);
                console.log(`  Jobs Matched: ${stat.jobs_matched}`);
                console.log(`  Applications Sent: ${stat.applications_sent}`);

                if (stat.metrics && stat.metrics.storage_mb) {
                    const usagePercent = (stat.metrics.storage_mb / 500) * 100;
                    const usageColor = usagePercent > 80 ? colors.red :
                        usagePercent > 60 ? colors.yellow : colors.green;

                    console.log(`  Storage: ${usageColor}${stat.metrics.storage_mb.toFixed(2)} MB (${usagePercent.toFixed(2)}% of 500MB)${colors.reset}`);
                }
            });
        } else {
            console.log(`${colors.yellow}⚠ No daily statistics available yet${colors.reset}`);
        }
    } catch (error) {
        console.error(`${colors.red}Error checking daily statistics: ${error.message}${colors.reset}`);
    }

    // Make storage projections
    await makeProjections(supabase);

    console.log(`\n${colors.green}Storage check completed.${colors.reset}`);
    console.log(`\n${colors.cyan}Next Steps:${colors.reset}`);
    console.log(`1. If approaching limits, consider running archive_old_jobs() function`);
    console.log(`2. Adjust compression settings if needed`);
    console.log(`3. Check query performance with explain analyze`);
}

// Check storage manually if view doesn't exist
async function checkStorageManually(supabase) {
    console.log(`\n${colors.blue}=== Manual Storage Check ===${colors.reset}`);

    // Get table sizes
    const sizeSQL = `
    SELECT 
        pg_size_pretty(pg_database_size(current_database())) as database_size,
        pg_size_pretty(pg_total_relation_size('companies')) as companies_size,
        pg_size_pretty(pg_total_relation_size('jobs')) as jobs_size,
        pg_size_pretty(pg_total_relation_size('applications')) as applications_size,
        pg_size_pretty(pg_total_relation_size('daily_stats')) as stats_size
    `;

    try {
        const { data: sizeData, error: sizeError } = await supabase.rpc('exec_sql_with_results', { sql: sizeSQL });

        if (sizeError) {
            console.log(`${colors.red}✗ Could not get table sizes: ${sizeError.message}${colors.reset}`);
        } else if (sizeData && sizeData.length > 0) {
            const sizes = sizeData[0];
            console.log(`${colors.cyan}Database Size: ${sizes.database_size}${colors.reset}`);
            console.log(`${colors.cyan}Companies Table: ${sizes.companies_size}${colors.reset}`);
            console.log(`${colors.cyan}Jobs Table: ${sizes.jobs_size}${colors.reset}`);
            console.log(`${colors.cyan}Applications Table: ${sizes.applications_size}${colors.reset}`);
            console.log(`${colors.cyan}Daily Stats Table: ${sizes.stats_size}${colors.reset}`);
        }
    } catch (error) {
        console.error(`${colors.red}Error checking table sizes: ${error.message}${colors.reset}`);
    }

    // Count records
    try {
        const { data: jobsCount, error: jobsError } = await supabase
            .from('jobs')
            .select('count', { count: 'exact', head: true });

        const { data: activeCount, error: activeError } = await supabase
            .from('jobs')
            .select('count', { count: 'exact', head: true })
            .eq('is_active', true);

        const { data: archivedCount, error: archivedError } = await supabase
            .from('jobs')
            .select('count', { count: 'exact', head: true })
            .not('archived_at', 'is', null);

        console.log(`\n${colors.cyan}Record Counts:${colors.reset}`);
        console.log(`  Total Jobs: ${jobsError ? 'error' : jobsCount}`);
        console.log(`  Active Jobs: ${activeError ? 'error' : activeCount}`);
        console.log(`  Archived Jobs: ${archivedError ? 'error' : archivedCount}`);
    } catch (error) {
        console.error(`${colors.red}Error counting records: ${error.message}${colors.reset}`);
    }
}

// Make storage projections
async function makeProjections(supabase) {
    console.log(`\n${colors.blue}=== Storage Projections ===${colors.reset}`);

    try {
        // Get current database size in MB
        const sizeSQL = `
        SELECT pg_database_size(current_database()) / 1024 / 1024 as size_mb
        `;

        const { data: sizeData, error: sizeError } = await supabase.rpc('exec_sql_with_results', { sql: sizeSQL });

        if (sizeError) {
            throw new Error(`Could not get database size: ${sizeError.message}`);
        }

        const currentSizeMB = sizeData[0].size_mb;

        // Get average job size
        const jobSizeSQL = `
        SELECT 
            COUNT(*) as job_count,
            pg_total_relation_size('jobs') / 1024.0 / 1024.0 as jobs_mb
        FROM jobs
        `;

        const { data: jobData, error: jobError } = await supabase.rpc('exec_sql_with_results', { sql: jobSizeSQL });

        if (jobError) {
            throw new Error(`Could not get job size data: ${jobError.message}`);
        }

        const jobCount = parseInt(jobData[0].job_count) || 1; // Avoid division by zero
        const jobsMB = parseFloat(jobData[0].jobs_mb) || 0;
        const avgJobSizeKB = (jobsMB * 1024) / jobCount;

        console.log(`${colors.cyan}Current Database Size: ${currentSizeMB.toFixed(2)} MB${colors.reset}`);
        console.log(`${colors.cyan}Current Job Count: ${jobCount}${colors.reset}`);
        console.log(`${colors.cyan}Average Job Size: ${avgJobSizeKB.toFixed(2)} KB${colors.reset}`);

        // Calculate free space
        const freeMB = 500 - currentSizeMB;
        const freePercent = (freeMB / 500) * 100;

        // Calculate capacity
        const remainingCapacity = Math.floor((freeMB * 1024) / avgJobSizeKB);

        const capacityColor = freePercent < 20 ? colors.red :
            freePercent < 40 ? colors.yellow : colors.green;

        console.log(`${capacityColor}Free Space: ${freeMB.toFixed(2)} MB (${freePercent.toFixed(2)}% available)${colors.reset}`);
        console.log(`${capacityColor}Estimated Remaining Capacity: ~${remainingCapacity} more jobs${colors.reset}`);

        // Project when we'll hit the limit
        if (jobCount > 0 && currentSizeMB > 0) {
            // Get growth rate from daily_stats if available
            const { data: statsData, error: statsError } = await supabase
                .from('daily_stats')
                .select('date, jobs_scraped, metrics')
                .order('date', { ascending: false })
                .limit(7);

            if (!statsError && statsData && statsData.length >= 2) {
                // Calculate average daily job additions
                let totalNewJobs = 0;
                statsData.forEach(day => {
                    totalNewJobs += day.jobs_scraped || 0;
                });
                const avgDailyJobs = totalNewJobs / statsData.length;

                if (avgDailyJobs > 0) {
                    const daysUntilFull = Math.floor(remainingCapacity / avgDailyJobs);
                    const fullDate = new Date();
                    fullDate.setDate(fullDate.getDate() + daysUntilFull);

                    const warningColor = daysUntilFull < 7 ? colors.red :
                        daysUntilFull < 30 ? colors.yellow : colors.green;

                    console.log(`${warningColor}At current rate (${avgDailyJobs.toFixed(1)} jobs/day), storage limit reached: ${fullDate.toISOString().split('T')[0]}${colors.reset}`);
                    console.log(`${warningColor}Days until full: ~${daysUntilFull} days${colors.reset}`);
                }
            } else {
                console.log(`${colors.yellow}⚠ Not enough historical data to project growth rate${colors.reset}`);
            }
        }
    } catch (error) {
        console.log(`${colors.yellow}⚠ Could not make storage projections: ${error.message}${colors.reset}`);
    }
}

// Run the storage check
checkStorage().catch(error => {
    console.error(`${colors.red}Unhandled error: ${error.message}${colors.reset}`);
    process.exit(1);
});