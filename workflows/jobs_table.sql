-- Jobs table for storing job listings collected from Adzuna API
CREATE TABLE IF NOT EXISTS public.jobs (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    company TEXT,
    location TEXT,
    url TEXT,
    description TEXT,
    salary_min NUMERIC,
    salary_max NUMERIC,
    created TIMESTAMP,
    category TEXT,
    contract_type TEXT,
    contract_time TEXT,
    scraped_at TIMESTAMP NOT NULL DEFAULT NOW(),
    source TEXT NOT NULL DEFAULT 'adzuna',
    match_score NUMERIC,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Metadata for tracking
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for faster querying
CREATE INDEX IF NOT EXISTS idx_jobs_company ON public.jobs(company);
CREATE INDEX IF NOT EXISTS idx_jobs_location ON public.jobs(location);
CREATE INDEX IF NOT EXISTS idx_jobs_category ON public.jobs(category);
CREATE INDEX IF NOT EXISTS idx_jobs_created ON public.jobs(created);
CREATE INDEX IF NOT EXISTS idx_jobs_scraped_at ON public.jobs(scraped_at);
CREATE INDEX IF NOT EXISTS idx_jobs_is_active ON public.jobs(is_active);

-- Function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function whenever a row is updated
DROP TRIGGER IF EXISTS jobs_updated_at ON public.jobs;
CREATE TRIGGER jobs_updated_at
BEFORE UPDATE ON public.jobs
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

-- Comment on table
COMMENT ON TABLE public.jobs IS 'Job listings collected from various sources including Adzuna API';

-- Comments on columns
COMMENT ON COLUMN public.jobs.id IS 'Unique identifier for the job, uses the source ID';
COMMENT ON COLUMN public.jobs.title IS 'Job title';
COMMENT ON COLUMN public.jobs.company IS 'Company name';
COMMENT ON COLUMN public.jobs.location IS 'Job location';
COMMENT ON COLUMN public.jobs.url IS 'URL to the job posting';
COMMENT ON COLUMN public.jobs.description IS 'Job description';
COMMENT ON COLUMN public.jobs.salary_min IS 'Minimum salary if available';
COMMENT ON COLUMN public.jobs.salary_max IS 'Maximum salary if available';
COMMENT ON COLUMN public.jobs.created IS 'When the job was created/posted';
COMMENT ON COLUMN public.jobs.category IS 'Job category or industry';
COMMENT ON COLUMN public.jobs.contract_type IS 'Type of contract (full_time, part_time, etc.)';
COMMENT ON COLUMN public.jobs.contract_time IS 'Duration of contract (permanent, temporary, etc.)';
COMMENT ON COLUMN public.jobs.scraped_at IS 'When the job was collected';
COMMENT ON COLUMN public.jobs.source IS 'Source of the job listing (adzuna, linkedin, etc.)';
COMMENT ON COLUMN public.jobs.match_score IS 'Calculated match score for the job';
COMMENT ON COLUMN public.jobs.is_active IS 'Whether the job is still active';
COMMENT ON COLUMN public.jobs.created_at IS 'When the record was created in the database';
COMMENT ON COLUMN public.jobs.updated_at IS 'When the record was last updated in the database'; 