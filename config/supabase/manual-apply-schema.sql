-- Job Automation Database Schema
-- Optimized for Supabase Free Tier (500MB limit)
-- Designed for Canadian PR job tracking

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Lean companies table (est. 10KB per company)
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    domain TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Efficient jobs table (est. 5KB per job)
CREATE TABLE jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    external_id TEXT UNIQUE, -- Original job ID from source
    title TEXT NOT NULL,
    company_id UUID REFERENCES companies(id),
    location TEXT NOT NULL,
    remote_type TEXT CHECK (remote_type IN ('onsite', 'remote', 'hybrid')),
    
    -- Store all requirements in JSONB to save space
    requirements JSONB DEFAULT '{}',
    -- Compressed description (saves 60% space)
    description_compressed BYTEA,
    
    -- Canadian PR specific fields
    noc_code TEXT,
    pr_eligible BOOLEAN DEFAULT false,
    
    -- Dates and status
    posted_date DATE,
    deadline DATE,
    scraped_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    source TEXT NOT NULL,
    url TEXT NOT NULL,
    salary_info JSONB,
    
    -- For archiving
    archived_at TIMESTAMP WITH TIME ZONE
);

-- Minimal applications table (est. 1KB per application)
CREATE TABLE applications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'interested',
    match_score DECIMAL(3,2),
    
    -- Store all notes and keywords in JSONB
    analysis JSONB DEFAULT '{}',
    
    -- Track updates
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Summary statistics table (updated daily)
CREATE TABLE daily_stats (
    date DATE PRIMARY KEY,
    jobs_scraped INTEGER DEFAULT 0,
    jobs_matched INTEGER DEFAULT 0,
    applications_sent INTEGER DEFAULT 0,
    
    -- Store detailed metrics as JSONB
    metrics JSONB DEFAULT '{}'
);

-- Create indexes for performance
CREATE INDEX idx_jobs_active ON jobs(is_active, scraped_at DESC);
CREATE INDEX idx_jobs_location ON jobs(location);
CREATE INDEX idx_jobs_title ON jobs USING gin(to_tsvector('english', title));
CREATE INDEX idx_applications_status ON applications(status);
CREATE INDEX idx_applications_score ON applications(match_score DESC);

-- Text compression function
CREATE OR REPLACE FUNCTION compress_text(input TEXT) 
RETURNS BYTEA AS $$
BEGIN
    RETURN compress(input::bytea);
END;
$$ LANGUAGE plpgsql;

-- Text decompression function
CREATE OR REPLACE FUNCTION decompress_text(input BYTEA) 
RETURNS TEXT AS $$
BEGIN
    RETURN convert_from(decompress(input), 'UTF8');
END;
$$ LANGUAGE plpgsql;

-- Auto-archive old jobs
CREATE OR REPLACE FUNCTION archive_old_jobs() 
RETURNS void AS $$
BEGIN
    UPDATE jobs 
    SET archived_at = NOW(), is_active = false
    WHERE scraped_at < NOW() - INTERVAL '30 days' 
    AND is_active = true;
END;
$$ LANGUAGE plpgsql;

-- View for storage monitoring
CREATE VIEW storage_monitor AS
SELECT 
    pg_size_pretty(pg_database_size(current_database())) as database_size,
    pg_size_pretty(pg_total_relation_size('jobs')) as jobs_table_size,
    pg_size_pretty(pg_total_relation_size('applications')) as applications_table_size,
    COUNT(*) FILTER (WHERE is_active = true) as active_jobs,
    COUNT(*) FILTER (WHERE archived_at IS NOT NULL) as archived_jobs
FROM jobs;

-- Automatic maintenance
CREATE OR REPLACE FUNCTION maintain_database() 
RETURNS void AS $$
BEGIN
    -- Archive old jobs
    PERFORM archive_old_jobs();
    
    -- Update statistics
    ANALYZE jobs;
    ANALYZE applications;
    
    -- Log current usage
    INSERT INTO daily_stats (date, metrics)
    VALUES (CURRENT_DATE, 
        jsonb_build_object(
            'storage_mb', pg_database_size(current_database()) / 1024 / 1024,
            'active_jobs', (SELECT COUNT(*) FROM jobs WHERE is_active = true)
        )
    )
    ON CONFLICT (date) DO UPDATE
    SET metrics = daily_stats.metrics || EXCLUDED.metrics;
END;
$$ LANGUAGE plpgsql;

-- Enable RLS (but policies inactive for now)
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;

-- Basic policy structure (currently allows all)
CREATE POLICY "Allow all for now" ON jobs FOR ALL TO anon, authenticated USING (true);
CREATE POLICY "Allow all for now" ON applications FOR ALL TO anon, authenticated USING (true);

-- Function to insert a job with compressed description
CREATE OR REPLACE FUNCTION insert_job_with_compression(
    p_external_id TEXT,
    p_title TEXT,
    p_company_name TEXT,
    p_location TEXT,
    p_remote_type TEXT,
    p_description TEXT,
    p_requirements JSONB,
    p_noc_code TEXT,
    p_posted_date DATE,
    p_source TEXT,
    p_url TEXT,
    p_salary_info JSONB
) RETURNS UUID AS $$
DECLARE
    v_company_id UUID;
    v_job_id UUID;
BEGIN
    -- Get or create company
    SELECT id INTO v_company_id FROM companies WHERE name = p_company_name;
    
    IF v_company_id IS NULL THEN
        INSERT INTO companies (name, domain)
        VALUES (p_company_name, 
                CASE 
                    WHEN p_company_name ~ '^\s*([A-Za-z0-9][A-Za-z0-9-]+)\s*' 
                    THEN regexp_replace(lower(p_company_name), '\s+', '') || '.com'
                    ELSE NULL
                END)
        RETURNING id INTO v_company_id;
    END IF;
    
    -- Insert job with compressed description
    INSERT INTO jobs (
        external_id, 
        title, 
        company_id, 
        location, 
        remote_type, 
        description_compressed, 
        requirements, 
        noc_code, 
        posted_date, 
        source, 
        url, 
        salary_info
    ) VALUES (
        p_external_id,
        p_title,
        v_company_id,
        p_location,
        p_remote_type,
        compress_text(p_description),
        p_requirements,
        p_noc_code,
        p_posted_date,
        p_source,
        p_url,
        p_salary_info
    ) RETURNING id INTO v_job_id;
    
    RETURN v_job_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get job with decompressed description
CREATE OR REPLACE FUNCTION get_job_with_description(p_job_id UUID) 
RETURNS TABLE (
    id UUID,
    title TEXT,
    company_name TEXT,
    location TEXT,
    remote_type TEXT,
    description TEXT,
    requirements JSONB,
    noc_code TEXT,
    pr_eligible BOOLEAN,
    posted_date DATE,
    source TEXT,
    url TEXT,
    salary_info JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        j.id,
        j.title,
        c.name as company_name,
        j.location,
        j.remote_type,
        decompress_text(j.description_compressed) as description,
        j.requirements,
        j.noc_code,
        j.pr_eligible,
        j.posted_date,
        j.source,
        j.url,
        j.salary_info
    FROM jobs j
    JOIN companies c ON j.company_id = c.id
    WHERE j.id = p_job_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_applications_updated_at
BEFORE UPDATE ON applications
FOR EACH ROW
EXECUTE PROCEDURE update_updated_at_column();

-- Test compression function
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

-- Create a scheduled task to run maintenance daily
COMMENT ON FUNCTION maintain_database() IS 'Run daily to archive old jobs and update statistics';

-- Insert sample data for testing
DO $$
DECLARE
    v_company_id UUID;
    long_description TEXT := 'This is a sample job description that would typically be much longer. ' || 
                          'It includes details about the position, responsibilities, qualifications, ' ||
                          'and company information. Imagine this text being 10-20 times longer with full paragraphs. ' ||
                          'This is just a placeholder to test the compression functionality.';
BEGIN
    -- Insert a sample company
    INSERT INTO companies (name, domain) 
    VALUES ('Sample Tech Company', 'sampletechcompany.com')
    RETURNING id INTO v_company_id;

    -- Insert a sample job with compression
    PERFORM insert_job_with_compression(
        'SAMPLE-JOB-123',  -- external_id
        'Senior Software Developer',  -- title
        'Sample Tech Company',  -- company_name (will reuse existing)
        'Toronto, Canada',  -- location
        'hybrid',  -- remote_type
        long_description || long_description || long_description,  -- description
        '{"required": ["JavaScript", "React", "Node.js"], "preferred": ["TypeScript", "AWS"]}'::jsonb,  -- requirements
        '21311',  -- noc_code
        CURRENT_DATE,  -- posted_date
        'manual',  -- source
        'https://example.com/jobs/123',  -- url
        '{"min": 100000, "max": 130000, "currency": "CAD"}'::jsonb  -- salary_info
    );

    -- Update daily stats
    INSERT INTO daily_stats (date, jobs_scraped, jobs_matched, applications_sent, metrics)
    VALUES (
        CURRENT_DATE, 
        1, 
        1, 
        0, 
        jsonb_build_object(
            'storage_mb', pg_database_size(current_database()) / 1024 / 1024,
            'active_jobs', 1,
            'test_run', true
        )
    );
END $$; 