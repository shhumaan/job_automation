/**
 * Test script to validate the Adzuna client integration with n8n workflow
 * This simulates the functionality that will be executed in the n8n Code node
 */

const AdzunaClient = require('../adzuna-client');
const jobTitles = require('../job-titles');

async function testN8nIntegration() {
    console.log('Testing n8n workflow integration...');
    console.log('----------------------------------');

    try {
        // Create Adzuna client instance
        const client = new AdzunaClient();
        console.log('✅ AdzunaClient initialized');

        // Get 40 daily jobs (same as n8n Code node)
        console.log('\nFetching jobs from Adzuna API...');
        const jobs = await client.getDailyJobs(jobTitles, 'Ontario', 40);
        console.log(`✅ Retrieved ${jobs.length} jobs`);

        // Add metadata (same as n8n Code node)
        console.log('\nEnriching job data with metadata...');
        const enrichedJobs = jobs.map(job => ({
            ...job,
            scraped_at: new Date().toISOString(),
            source: 'adzuna',
            match_score: null, // Will be calculated in next phase
            is_active: true
        }));
        console.log('✅ Jobs enriched with metadata');

        // Deduplicate (same as n8n Function node)
        console.log('\nDeduplicating jobs...');
        const uniqueJobs = {};
        enrichedJobs.forEach(job => {
            uniqueJobs[job.id] = job;
        });
        const dedupedJobs = Object.values(uniqueJobs);
        console.log(`✅ After deduplication: ${dedupedJobs.length} jobs`);

        // Print job statistics
        console.log('\nJob Statistics:');
        console.log('----------------------------------');

        // Count by company
        const companyCounts = {};
        dedupedJobs.forEach(job => {
            const company = job.company || 'Unknown';
            companyCounts[company] = (companyCounts[company] || 0) + 1;
        });

        console.log('\nTop Companies:');
        Object.entries(companyCounts)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 5)
            .forEach(([company, count]) => {
                console.log(`- ${company}: ${count} jobs`);
            });

        // Sample jobs
        console.log('\nSample Jobs:');
        dedupedJobs.slice(0, 3).forEach((job, index) => {
            console.log(`\nJob ${index + 1}:`);
            console.log(`- Title: ${job.title}`);
            console.log(`- Company: ${job.company}`);
            console.log(`- Location: ${job.location}`);
            console.log(`- URL: ${job.url}`);
            console.log(`- Scraped at: ${job.scraped_at}`);
        });

        console.log('\n----------------------------------');
        console.log('✅ n8n workflow integration test successful');
        console.log('This data would be sent to Supabase and summarized in an email');

    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.error(error);
    }
}

// Run the test
testN8nIntegration();