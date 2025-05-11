#!/usr/bin/env node

/**
 * Job Automation System Validation Script
 * 
 * This script validates the full setup of the job automation system:
 * 1. Docker services status
 * 2. Supabase connection
 * 3. n8n workflow status
 * 4. Environment variables
 * 5. Workflow IDs
 */

require('dotenv').config({ path: '../.env' });
const { execSync } = require('child_process');
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

// Main validation function
async function validateSetup() {
    console.log(`\n${colors.cyan}=== Job Automation System Validation ====${colors.reset}\n`);

    // Step 1: Check Docker services
    console.log(`${colors.blue}1. Checking Docker services...${colors.reset}`);
    try {
        const dockerOutput = execSync('docker ps').toString();
        const services = ['n8n', 'redis', 'nginx', 'ollama'];

        services.forEach(service => {
            if (dockerOutput.includes(service)) {
                console.log(`${colors.green}✓ ${service} is running${colors.reset}`);
            } else {
                console.log(`${colors.red}✗ ${service} is not running${colors.reset}`);
            }
        });
    } catch (error) {
        console.log(`${colors.red}✗ Error checking Docker services: ${error.message}${colors.reset}`);
    }

    // Step 2: Check Supabase connection
    console.log(`\n${colors.blue}2. Checking Supabase connection...${colors.reset}`);
    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_API_KEY;

    if (!supabaseUrl || !supabaseKey) {
        console.log(`${colors.red}✗ Missing Supabase credentials in .env file${colors.reset}`);
    } else {
        try {
            const supabase = createClient(supabaseUrl, supabaseKey);
            const { data, error } = await supabase.from('jobs').select('count', { count: 'exact', head: true });

            if (error) {
                console.log(`${colors.red}✗ Supabase connection failed: ${error.message}${colors.reset}`);
            } else {
                console.log(`${colors.green}✓ Supabase connection successful${colors.reset}`);
            }
        } catch (error) {
            console.log(`${colors.red}✗ Supabase error: ${error.message}${colors.reset}`);
        }
    }

    // Step 3: Check n8n
    console.log(`\n${colors.blue}3. Checking n8n...${colors.reset}`);
    try {
        const healthOutput = execSync('curl -s http://localhost:5678/healthz').toString();

        if (healthOutput.includes('"status":"ok"')) {
            console.log(`${colors.green}✓ n8n health check passed${colors.reset}`);
        } else {
            console.log(`${colors.red}✗ n8n health check failed${colors.reset}`);
        }
    } catch (error) {
        console.log(`${colors.red}✗ Error checking n8n: ${error.message}${colors.reset}`);
    }

    // Step 4: Check workflow files
    console.log(`\n${colors.blue}4. Checking workflow files...${colors.reset}`);
    const requiredWorkflows = [
        'master_controller.json',
        'job_scraper_template.json',
        'data_processor.json',
        'error_handler.json',
        'performance_monitor.json'
    ];

    try {
        const filesOutput = execSync('ls -1 ../volumes/data/n8n/workflows').toString();

        requiredWorkflows.forEach(workflow => {
            if (filesOutput.includes(workflow)) {
                console.log(`${colors.green}✓ ${workflow} exists${colors.reset}`);
            } else {
                console.log(`${colors.red}✗ ${workflow} is missing${colors.reset}`);
            }
        });
    } catch (error) {
        console.log(`${colors.red}✗ Error checking workflow files: ${error.message}${colors.reset}`);
    }

    // Step 5: Check environment variables
    console.log(`\n${colors.blue}5. Checking environment variables...${colors.reset}`);
    const requiredEnvVars = [
        'EXTERNAL_VOLUME',
        'N8N_ENCRYPTION_KEY',
        'SUPABASE_URL',
        'SUPABASE_API_KEY',
        'JOB_SCRAPER_WORKFLOW_ID',
        'DATA_PROCESSOR_WORKFLOW_ID',
        'ERROR_HANDLER_WORKFLOW_ID',
        'PERFORMANCE_MONITOR_WORKFLOW_ID'
    ];

    requiredEnvVars.forEach(envVar => {
        if (process.env[envVar]) {
            console.log(`${colors.green}✓ ${envVar} is set${colors.reset}`);
        } else {
            console.log(`${colors.red}✗ ${envVar} is missing${colors.reset}`);
        }
    });

    console.log(`\n${colors.cyan}=== Validation Complete ====${colors.reset}\n`);
    console.log(`${colors.yellow}Next Steps:${colors.reset}`);
    console.log(`1. Ensure all workflows are active in n8n interface`);
    console.log(`2. Verify Supabase credentials are set in all workflow nodes`);
    console.log(`3. Test run the Master Controller workflow`);
    console.log(`4. Check for any error logs`);
}

// Run validation
validateSetup().catch(console.error);