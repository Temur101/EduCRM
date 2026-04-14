-- Run this in your Supabase SQL Editor

-- Create attendance table with lesson_date (date) column and status text
CREATE TABLE IF NOT EXISTS attendance (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id     uuid,
  student_id   uuid,
  lesson_date  date NOT NULL,
  status       text NOT NULL DEFAULT 'present',  -- 'present' | 'absent' | 'sick' | 'late'
  created_at   timestamptz DEFAULT now(),
  UNIQUE(student_id, group_id, lesson_date)
);

-- If table already exists, just make sure lesson_date column is there:
-- ALTER TABLE attendance ADD COLUMN IF NOT EXISTS lesson_date date;
-- ALTER TABLE attendance ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'present';

-- Enable Row Level Security (allow all for now)
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all attendance" ON attendance;
CREATE POLICY "Allow all attendance" ON attendance FOR ALL USING (true) WITH CHECK (true);
