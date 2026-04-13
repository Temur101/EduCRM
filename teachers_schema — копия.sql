
-- SQL to create the teachers table
CREATE TABLE teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    subject TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    percentage INTEGER, -- Share from the group in percentage
    status TEXT DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security (RLS)
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all actions for authenticated users
CREATE POLICY "Allow all for authenticated users" ON teachers
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Allow anon to read/write for now
CREATE POLICY "Allow all for anon" ON teachers
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);
