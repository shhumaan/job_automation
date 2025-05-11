#!/usr/bin/env node

/**
 * Supabase Query Performance Test
 * 
 * This script tests the performance of common queries against
 * the optimized Supabase schema to validate design decisions.
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
    cyan: '\x1b[36m'
};

// Define test queries
const testQueries = [{
        name: 'Recent active jobs',
        query: 'SELECT id, title, location, remote_type, posted_date FROM jobs WHERE is_active = true ORDER BY scraped_at DESC LIMIT 10',
        description: 'Get recent active jobs (should use idx_jobs_active)'
    },
    {
        name: 'Jobs by location',
        query: "SELECT id, title, location FROM jobs WHERE location ILIKE '%canada%' AND is_active = true LIMIT 10",
        description: 'Find jobs by location (should use idx_jobs_location)'
    },
    {
        name: 'Jobs by title search',
        query: "SELECT id, title, location FROM jobs WHERE to_tsvector('english', title) @@ to_tsquery('english', 'developer') AND is_active = true LIMIT 10",
        description: 'Search jobs by title keywords (should use idx_jobs_title)'
    },
    {
        name: 'Job with decompressed description',
        query: `
            SELECT 
                j.id, j.title, c.name as company_name, j.location, j.remote_type,
                decompress_text(j.description_compressed) as description
            FROM jobs j
            JOIN companies c ON j.company_id = c.id
            WHERE j.is_active = true
            LIMIT 1
        `,
        description: 'Test decompression function performance'
    },
    {
        name: 'PR eligible jobs',
        query: `
            SELECT id, title, location, noc_code
            FROM jobs
            WHERE is_active = true AND pr_eligible = true
            ORDER BY posted_date DESC
            LIMIT 10
        `,
        description: 'Find PR eligible jobs'
    },
    {
        name: 'Daily job counts',
        query: `
            SELECT 
                posted_date::date,
                COUNT(*) as job_count
            FROM jobs
            WHERE posted_date >= current_date - interval '30 days'
            GROUP BY posted_date::date
            ORDER BY posted_date::date DESC
        `,
        description: 'Get job count by day for the last 30 days'
    }
];

// Main function to test queries
async function testQueries() {
    console.log(`\n${colors.cyan}=== Supabase Query Performance Test ====${colors.reset}\n`);

    // Get Supabase credentials
    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_API_KEY;

    if (!supabaseUrl || !supabaseKey) {
        console.error(`${colors.red}Error: SUPABASE_URL and SUPABASE_API_KEY must be set in .env file${colors.reset}`);
        process.exit(1);
    }

    // Create Supabase client
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Test each query
    for (const test of testQueries) {
        console.log(`\n${colors.blue}=== Testing: ${test.name} ===${colors.reset}`);
        console.log(`${colors.yellow}${test.description}${colors.reset}`);

        try {
            console.log(`${colors.magenta}Query:${colors.reset}\n${test.query}`);

            // First, get query plan
            const explainQuery = `EXPLAIN ANALYZE ${test.query}`;
            const startExplain = Date.now();

            const { data: explainData, error: explainError } = await supabase.rpc('exec_sql_with_results', {
                sql: explainQuery
            });

            const explainTime = Date.now() - startExplain;

            // Then, execute actual query and time it
            const startQuery = Date.now();
            const { data: queryData, error: queryError } = await supabase.rpc('exec_sql_with_results', {
                sql: test.query
            });
            const queryTime = Date.now() - startQuery;

            if (explainError) {
                console.log(`${colors.red}Error getting query plan: ${explainError.message}${colors.reset}`);
            } else {
                console.log(`\n${colors.green}Query Plan:${colors.reset}`);
                explainData.forEach(row => {
                    console.log(`  ${row["QUERY PLAN"]}`);
                });
            }

            if (queryError) {
                console.log(`${colors.red}Error executing query: ${queryError.message}${colors.reset}`);
            } else {
                console.log(`\n${colors.green}Results: ${queryData.length} rows${colors.reset}`);
                console.log(`${colors.green}Execution Time: ${queryTime}ms${colors.reset}`);

                // Print a sample of the results
                if (queryData.length > 0) {
                    console.log(`\n${colors.cyan}Sample Result:${colors.reset}`);
                    const sample = queryData[0];
                    const keys = Object.keys(sample);

                    // Skip description field in the output (too verbose)
                    keys.forEach(key => {
                        if (key !== 'description') {
                            const value = sample[key];
                            console.log(`  ${key}: ${value === null ? 'null' : value.toString().substring(0, 50)}`);
                        } else {
                            console.log(`  description: [COMPRESSED DATA]`);
                        }
                    });
                }
            }
        } catch (error) {
            console.error(`${colors.red}Exception: ${error.message}${colors.reset}`);
        }
    }

    console.log(`\n${colors.green}Query performance tests completed.${colors.reset}`);
}

// Run the tests
testQueries().catch(error => {
    console.error(`${colors.red}Unhandled error: ${error.message}${colors.reset}`);
    process.exit(1);
});