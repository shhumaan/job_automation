const AdzunaClient = require('../adzuna-client');
const jobTitles = require('../job-titles');
const fs = require('fs');
const path = require('path');

async function testDailyJobs() {
    const client = new AdzunaClient();

    console.log('Testing daily job retrieval...');
    console.log('Target: 40 jobs from Ontario');

    const jobs = await client.getDailyJobs(jobTitles, 'Ontario', 40);

    console.log(`\nResults:`);
    console.log(`Total jobs found: ${jobs.length}`);
    console.log(`Unique companies: ${new Set(jobs.map(j => j.company)).size}`);

    // Show sample jobs
    console.log('\nSample jobs:');
    jobs.slice(0, 3).forEach((job, i) => {
        console.log(`${i + 1}. ${job.title} at ${job.company} (${job.location})`);
    });

    // Show job title distribution
    const titleCounts = {};
    jobs.forEach(job => {
        titleCounts[job.title] = (titleCounts[job.title] || 0) + 1;
    });

    console.log('\nJob titles found:');
    Object.entries(titleCounts)
        .sort(([, a], [, b]) => b - a)
        .slice(0, 5)
        .forEach(([title, count]) => {
            console.log(`- ${title}: ${count}`);
        });

    // Save results to a file
    const resultsDir = path.join(process.cwd(), 'results');
    if (!fs.existsSync(resultsDir)) {
        fs.mkdirSync(resultsDir, { recursive: true });
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const resultsPath = path.join(resultsDir, `daily-jobs-${timestamp}.json`);
    fs.writeFileSync(resultsPath, JSON.stringify(jobs, null, 2));
    console.log(`\nResults saved to: ${resultsPath}`);

    return jobs;
}

// Run the test if this file is executed directly
if (require.main === module) {
    testDailyJobs()
        .then(jobs => {
            console.log('\nTest completed successfully');
        })
        .catch(error => {
            console.error('\nTest failed:', error);
            process.exit(1);
        });
}

module.exports = { testDailyJobs };