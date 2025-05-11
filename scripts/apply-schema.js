#!/usr/bin/env node

/**
 * Supabase Schema Migration Script
 * 
 * This script applies the optimized database schema to Supabase
 * and validates the setup.
 */

require('dotenv').config({ path: '../.env' });
const fs = require('fs');
const path = require('path');
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

// Main function
async function applySchema() {
    console.log(`\n${colors.cyan}=== Applying Optimized Schema to Supabase ====${colors.reset}\n`);

    // Get Supabase credentials
    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_API_KEY;

    if (!supabaseUrl || !supabaseKey) {
        console.error(`${colors.red}Error: SUPABASE_URL and SUPABASE_API_KEY must be set in .env file${colors.reset}`);
        process.exit(1);
    }

    // Create Supabase client
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Read the schema file
    const schemaPath = path.join(__dirname, '../config/supabase/schema.sql');
    let schemaSQL;

    try {
        schemaSQL = fs.readFileSync(schemaPath, 'utf8');
    } catch (error) {
        console.error(`${colors.red}Error: Could not read schema file: ${error.message}${colors.reset}`);
        process.exit(1);
    }

    // Split the schema into separate statements
    const statements = schemaSQL
        .split(';')
        .map(statement => statement.trim())
        .filter(statement => statement.length > 0);

    console.log(`${colors.blue}Found ${statements.length} SQL statements to execute...${colors.reset}`);

    // Execute each statement
    let successCount = 0;
    let failureCount = 0;

    for (let i = 0; i < statements.length; i++) {
        const statement = statements[i];
        const statementPreview = statement.length > 50 ?
            statement.substring(0, 50) + '...' :
            statement;

        try {
            console.log(`${colors.yellow}Executing statement ${i+1}/${statements.length}: ${statementPreview}${colors.reset}`);

            // Add semicolon back for execution
            const { error } = await supabase.rpc('exec_sql', { sql: statement + ';' });

            if (error) {
                console.error(`${colors.red}Error: ${error.message}${colors.reset}`);
                failureCount++;
            } else {
                console.log(`${colors.green}Success!${colors.reset}`);
                successCount++;
            }
        } catch (error) {
            console.error(`${colors.red}Exception: ${error.message}${colors.reset}`);
            failureCount++;
        }
    }

    console.log(`\n${colors.cyan}=== Schema Migration Summary ====${colors.reset}`);
    console.log(`${colors.green}Successful statements: ${successCount}${colors.reset}`);
    console.log(`${colors.red}Failed statements: ${failureCount}${colors.reset}`);

    // Validate tables
    console.log(`\n${colors.blue}Validating tables...${colors.reset}`);

    const requiredTables = ['companies', 'jobs', 'applications', 'daily_stats'];

    for (const table of requiredTables) {
        const { data, error } = await supabase
            .from(table)
            .select('count', { count: 'exact', head: true });

        if (error) {
            console.log(`${colors.red}✗ Table '${table}' validation failed: ${error.message}${colors.reset}`);
        } else {
            console.log(`${colors.green}✓ Table '${table}' exists${colors.reset}`);
        }
    }

    // Check functions
    console.log(`\n${colors.blue}Testing compression functions...${colors.reset}`);

    try {
        const testText = "This is a test description with lots of words to compress. ".repeat(20);

        // This is a workaround since we can't directly call our compression functions from JS
        const { data: insertData, error: insertError } = await supabase.rpc('test_compression', {
            test_text: testText
        });

        if (insertError) {
            console.log(`${colors.red}✗ Compression test failed: ${insertError.message}${colors.reset}`);
        } else {
            console.log(`${colors.green}✓ Compression functions working${colors.reset}`);
            console.log(`${colors.cyan}Original size: ${testText.length} bytes${colors.reset}`);
            console.log(`${colors.cyan}Compressed: ${insertData.compressed_size} bytes${colors.reset}`);
            console.log(`${colors.cyan}Compression ratio: ${Math.round((1 - insertData.compressed_size / testText.length) * 100)}%${colors.reset}`);
        }
    } catch (error) {
        console.log(`${colors.yellow}! Could not test compression functions directly. You will need to create a test_compression function manually.${colors.reset}`);
    }

    console.log(`\n${colors.green}Schema migration completed.${colors.reset}`);
    console.log(`\n${colors.cyan}Next Steps:${colors.reset}`);
    console.log(`1. Set up scheduled function for daily maintenance (maintain_database)`);
    console.log(`2. Add the custom RPC functions in Supabase dashboard if needed`);
    console.log(`3. Test inserting and querying jobs with compression`);
    console.log(`4. Check storage usage via the storage_monitor view`);
}

// Add test_compression function
async function createTestFunction(supabase) {
    const functionSQL = `
    CREATE OR REPLACE FUNCTION test_compression(test_text TEXT)
    RETURNS JSONB AS $$
    DECLARE
        compressed_data BYTEA;
        decompressed_text TEXT;
        result JSONB;
    BEGIN
        compressed_data := compress_text(test_text);
        decompressed_text := decompress_text(compressed_data);
        
        result := jsonb_build_object(
            'original_text', substring(test_text, 1, 50) || '...',
            'original_size', length(test_text),
            'compressed_size', length(compressed_data),
            'decompressed_size', length(decompressed_text),
            'match', decompressed_text = test_text
        );
        
        RETURN result;
    END;
    $$ LANGUAGE plpgsql;
    `;

    return await supabase.rpc('exec_sql', { sql: functionSQL });
}

// Run the migration
applySchema().catch(error => {
    console.error(`${colors.red}Unhandled error: ${error.message}${colors.reset}`);
    process.exit(1);
});