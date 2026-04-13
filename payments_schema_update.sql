-- Run this in your Supabase SQL Editor
-- Add comment and month columns to the payments table

ALTER TABLE payments ADD COLUMN IF NOT EXISTS comment text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS month text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS student_id uuid REFERENCES students(id);

-- Optional: Update existing records with a default value for month if needed
-- UPDATE payments SET month = 'Noma''lum' WHERE month IS NULL;
