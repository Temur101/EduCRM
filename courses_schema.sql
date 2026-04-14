
-- SQL to create the courses table
CREATE TABLE courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    teacher_id UUID REFERENCES teachers(id) ON DELETE SET NULL,
    price BIGINT,
    status TEXT DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security (RLS)
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all actions for authenticated users
CREATE POLICY "Allow all for authenticated users" ON courses
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Allow anon to read/write for now
CREATE POLICY "Allow all for anon" ON courses
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);
