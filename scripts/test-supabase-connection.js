#!/usr/bin/env node

/**
 * Supabase Connection Test Script
 * 
 * This script tests the connection to Supabase and validates:
 * 1. API connectivity
 * 2. Authentication works with the provided API key
 * 3. Database tables exist
 * 4. Basic CRUD operations work
 * 5. Free tier limits and current usage
 * 
 * Usage: node test-supabase-connection.js
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

// Configuration from environment
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_API_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error(`${colors.red}Error: SUPABASE_URL and SUPABASE_API_KEY must be set in .env file${colors.reset}`);
    process.exit(1);
}

// Create Supabase client
const supabase = createClient(supabaseUrl, supabaseKey);

// Test record for validation
const testRecord = {
    title: 'Test Job Position',
    company: 'Test Company',
    location: 'Test Location',
    description: 'Test job for connection validation',
    source: 'connection-test'
};

// Tables to check
const requiredTables = ['jobs', 'error_logs', 'performance_metrics'];

/**
 * Main function to test Supabase connection
 */
async function testConnection() {
    console.log(`\n${colors.cyan}=== Supabase Connection Test ====${colors.reset}\n`);
    console.log(`Supabase URL: ${supabaseUrl}`);

    try {
        // Step 1: Test basic connectivity
        console.log(`\n${colors.blue}1. Testing API connectivity...${colors.reset}`);
        const { data: connectionTest, error: connectionError } = await supabase.from('jobs').select('count', { count: 'exact', head: true });

        if (connectionError) throw new Error(`API connectivity test failed: ${connectionError.message}`);
        console.log(`${colors.green}✓ API connection successful${colors.reset}`);

        // Step 2: Verify required tables exist
        console.log(`\n${colors.blue}2. Verifying required tables...${colors.reset}`);

        for (const table of requiredTables) {
            const { error } = await supabase.from(table).select('count', { count: 'exact', head: true });

            if (error) {
                if (error.code === '42P01') { // Table does not exist
                    console.log(`${colors.red}✗ Table '${table}' does not exist${colors.reset}`);
                } else {
                    console.log(`${colors.red}✗ Error accessing table '${table}': ${error.message}${colors.reset}`);
                }
            } else {
                console.log(`${colors.green}✓ Table '${table}' exists${colors.reset}`);
            }
        }

        // Step 3: Test CRUD operations
        console.log(`\n${colors.blue}3. Testing CRUD operations...${colors.reset}`);

        // Create
        const { data: insertData, error: insertError } = await supabase
            .from('jobs')
            .insert(testRecord)
            .select();

        if (insertError) {
            console.log(`${colors.red}✗ Insert operation failed: ${insertError.message}${colors.reset}`);
        } else {
            console.log(`${colors.green}✓ Insert operation successful${colors.reset}`);

            const testId = insertData[0].id;

            // Read
            const { data: readData, error: readError } = await supabase
                .from('jobs')
                .select('*')
                .eq('id', testId);

            if (readError || !readData || readData.length === 0) {
                console.log(`${colors.red}✗ Read operation failed: ${readError?.message || 'No data returned'}${colors.reset}`);
            } else {
                console.log(`${colors.green}✓ Read operation successful${colors.reset}`);
            }

            // Update
            const { error: updateError } = await supabase
                .from('jobs')
                .update({ description: 'Updated test description' })
                .eq('id', testId);

            if (updateError) {
                console.log(`${colors.red}✗ Update operation failed: ${updateError.message}${colors.reset}`);
            } else {
                console.log(`${colors.green}✓ Update operation successful${colors.reset}`);
            }

            // Delete
            const { error: deleteError } = await supabase
                .from('jobs')
                .delete()
                .eq('id', testId);

            if (deleteError) {
                console.log(`${colors.red}✗ Delete operation failed: ${deleteError.message}${colors.reset}`);
            } else {
                console.log(`${colors.green}✓ Delete operation successful${colors.reset}`);
            }
        }

        // Step 4: Check free tier limits
        console.log(`\n${colors.blue}4. Checking free tier limits...${colors.reset}`);

        // Get database size
        const { data: sizeData, error: sizeError } = await supabase.rpc('get_size_of_tables');

        if (sizeError) {
            console.log(`${colors.yellow}! Unable to check database size: ${sizeError.message}${colors.reset}`);
        } else {
            // Format size data nicely
            console.log(`${colors.cyan}Database Size:${colors.reset}`);
            let totalSize = 0;

            if (Array.isArray(sizeData)) {
                sizeData.forEach(item => {
                    console.log(`  ${item.table_name}: ${formatBytes(parseInt(item.size_bytes))}`);
                    totalSize += parseInt(item.size_bytes);
                });

                console.log(`\n  ${colors.cyan}Total Size: ${formatBytes(totalSize)}${colors.reset}`);
                const percentUsed = (totalSize / (500 * 1024 * 1024)) * 100; // 500MB limit
                console.log(`  ${colors.cyan}Free Tier Usage: ${percentUsed.toFixed(2)}% of 500MB${colors.reset}`);

                if (percentUsed > 80) {
                    console.log(`  ${colors.yellow}⚠️  Warning: Database approaching free tier limit${colors.reset}`);
                }
            } else {
                console.log(`${colors.yellow}! Unexpected size data format${colors.reset}`);
            }
        }

        // Get row counts
        for (const table of requiredTables) {
            const { data, error, count } = await supabase
                .from(table)
                .select('*', { count: 'exact', head: true });

            if (error) {
                console.log(`${colors.yellow}! Unable to get row count for ${table}: ${error.message}${colors.reset}`);
            } else {
                console.log(`  ${table}: ${count || 0} rows`);
            }
        }

        console.log(`\n${colors.green}✅ Supabase Connection Test Complete${colors.reset}`);

    } catch (error) {
        console.error(`\n${colors.red}❌ Test failed: ${error.message}${colors.reset}`);
        process.exit(1);
    }
}

/**
 * Format bytes to human-readable format
 */
function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(decimals)) + ' ' + sizes[i];
}

// Run the test
testConnection();