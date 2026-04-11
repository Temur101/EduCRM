-- Run this in Supabase SQL Editor

-- Add discount column to students (stores UZS amount, not percentage)
ALTER TABLE students ADD COLUMN IF NOT EXISTS discount bigint DEFAULT 0;

-- If column already exists as integer, upgrade it to bigint:
-- ALTER TABLE students ALTER COLUMN discount TYPE bigint;
