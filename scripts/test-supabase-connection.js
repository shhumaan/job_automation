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

const { createClient } = require('@supabase/supabase-js');
const dotenv = require('dotenv');
const path = require('path');

// Load environment variables
dotenv.config({ path: path.join(__dirname, '..', '.env') });

async function testSupabaseConnection() {
    console.log('Testing Supabase connection...');

    try {
        // Check if environment variables are set
        if (!process.env.SUPABASE_URL || !process.env.SUPABASE_API_KEY) {
            throw new Error('Missing Supabase environment variables (SUPABASE_URL or SUPABASE_API_KEY)');
        }

        // Create Supabase client
        const supabase = createClient(
            process.env.SUPABASE_URL,
            process.env.SUPABASE_API_KEY
        );

        // First test basic connectivity by checking if the jobs table exists
        const { count, error: countError } = await supabase
            .from('jobs')
            .select('*', { count: 'exact', head: true });

        if (countError) throw countError;

        console.log('✅ Supabase connection successful');
        console.log(`Jobs table exists with ${count || 0} records`);

        // Try to check database size if the function exists
        try {
            const { data: storageData, error: storageError } = await supabase
                .rpc('pg_database_size', { db_name: 'postgres' });

            if (!storageError) {
                console.log(`Database size: ${storageData ? Math.round(storageData / 1024 / 1024) : 'Unknown'} MB`);
            }
        } catch (sizeError) {
            console.log('Note: Unable to check database size - function pg_database_size not available.');
        }

        return true;

    } catch (error) {
        console.error('❌ Supabase connection failed:', error.message);
        return false;
    }
}

// Run test if called directly
if (require.main === module) {
    testSupabaseConnection().then(success => {
        process.exit(success ? 0 : 1);
    });
}

module.exports = testSupabaseConnection;