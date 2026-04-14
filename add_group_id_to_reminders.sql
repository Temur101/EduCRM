-- Run this in your Supabase SQL Editor
ALTER TABLE payment_reminders
  ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES groups(id) ON DELETE SET NULL;
