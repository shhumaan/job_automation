const axios = require('axios');

class AdzunaClient {
    constructor() {
        this.app_id = '9d3a518c';
        this.app_key = 'dca4a33172bddec8f4a538c45aebd0b4';
        this.baseUrl = 'https://api.adzuna.com/v1/api/jobs/ca/search';
    }

    async searchJobs(jobTitle, location = 'Ontario', page = 1, daysAgo = 1) {
        try {
            // Ensure page is a valid integer
            page = parseInt(page, 10) || 1;

            // Log the request for debugging
            console.log(`Making API request for "${jobTitle}" in ${location} (page ${page})`);

            const params = {
                app_id: this.app_id,
                app_key: this.app_key,
                what: jobTitle,
                where: location,
                results_per_page: 50,
                // The max_days_old parameter was causing issues, so we'll handle recent jobs differently
                sort_by: 'date'
            };

            console.log(`API Request URL: ${this.baseUrl}/${page}`);
            console.log('Params:', JSON.stringify(params));

            const response = await axios.get(`${this.baseUrl}/${page}`, { params });

            console.log(`Response status: ${response.status}`);

            // If we get here, the request was successful
            return this.formatResults(response.data);
        } catch (error) {
            // More detailed error logging
            if (error.response) {
                // The request was made and the server responded with a status code
                // that falls out of the range of 2xx
                console.error(`Adzuna API error (Status ${error.response.status}):`,
                    error.response.data ? JSON.stringify(error.response.data) : 'No response data');
            } else if (error.request) {
                // The request was made but no response was received
                console.error('Adzuna API error: No response received');
            } else {
                // Something happened in setting up the request that triggered an Error
                console.error('Adzuna API error:', error.message);
            }

            return { error: error.message, results: [] };
        }
    }

    formatResults(data) {
        if (!data || !data.results) {
            console.log('No results found in response data');
            return { results: [] };
        }

        console.log(`Found ${data.results.length} results`);

        // Convert API response to our format
        const results = data.results.map(job => {
            // Handle potential missing fields safely
            const company = job.company && job.company.display_name ? job.company.display_name : 'Unknown Company';
            const location = job.location && job.location.display_name ? job.location.display_name : 'Unknown Location';
            const category = job.category && job.category.label ? job.category.label : 'Uncategorized';

            return {
                id: job.id,
                title: job.title || 'Unknown Title',
                company: company,
                location: location,
                url: job.redirect_url || '',
                description: job.description || '',
                salary_min: job.salary_min || null,
                salary_max: job.salary_max || null,
                created: job.created,
                category: category,
                contract_type: job.contract_type || 'full_time',
                contract_time: job.contract_time || 'permanent'
            };
        });

        return {
            results: results,
            count: data.count || 0
        };
    }

    async getDailyJobs(jobTitles, location = 'Ontario', targetCount = 40) {
        const allJobs = [];
        const seenIds = new Set();

        console.log(`Target: ${targetCount} jobs from ${location}`);

        // Search each job title
        for (const title of jobTitles) {
            console.log(`\nSearching for: ${title}`);

            // Try to get jobs - first page only
            const result = await this.searchJobs(title, location, 1);

            if (result.error) {
                console.log(`Error searching for "${title}": ${result.error}`);
                // Continue with the next job title
                continue;
            }

            // Filter out duplicates
            const newJobs = result.results.filter(job => {
                if (seenIds.has(job.id)) return false;
                seenIds.add(job.id);
                return true;
            });

            console.log(`Found ${newJobs.length} new unique jobs for "${title}"`);
            allJobs.push(...newJobs);

            // Stop if we have enough jobs
            if (allJobs.length >= targetCount) {
                console.log(`Reached target of ${targetCount} jobs, stopping search`);
                break;
            }

            // Rate limiting to avoid hitting API limits
            console.log('Waiting before next request...');
            await new Promise(resolve => setTimeout(resolve, 1000));
        }

        console.log(`\nTotal unique jobs found: ${allJobs.length}`);

        // Return only the target count (or fewer if not enough found)
        const finalJobs = allJobs.slice(0, targetCount);
        console.log(`Returning ${finalJobs.length} jobs`);

        return finalJobs;
    }
}

module.exports = AdzunaClient;