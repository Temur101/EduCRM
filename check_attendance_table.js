import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://derdfzohcuftfzvazsub.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlcmRmem9oY3VmdGZ6dmF6c3ViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwMzMzMzcsImV4cCI6MjA4NzYwOTMzN30.weUFnPj8gdmADy6vDZveFDp4XzFkqOwbgfiq20YehUs'
const supabase = createClient(supabaseUrl, supabaseKey)

async function check() {
  console.log('--- Checking attendance table ---');
  const { data, error } = await supabase.from('attendance').select('*').limit(3);

  if (error) {
    console.log('❌ Table "attendance" does NOT exist:', error.message);
    console.log('\nRun this SQL in Supabase SQL Editor:\n');
    console.log(`
CREATE TABLE IF NOT EXISTS attendance (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id     uuid,
  student_id   uuid,
  lesson_date  date NOT NULL,
  status       text NOT NULL DEFAULT 'present',
  created_at   timestamptz DEFAULT now(),
  UNIQUE(student_id, group_id, lesson_date)
);
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all attendance" ON attendance;
CREATE POLICY "Allow all attendance" ON attendance FOR ALL USING (true) WITH CHECK (true);
    `);
  } else {
    console.log('✅ Table exists! Rows found:', data.length);
    // Test insert
    const { error: ie } = await supabase.from('attendance').upsert([{
      group_id: '00000000-0000-0000-0000-000000000000',
      student_id: '00000000-0000-0000-0000-000000000000',
      lesson_date: '2026-01-01',
      status: 'present'
    }], { onConflict: 'student_id,group_id,lesson_date' });

    if (ie) {
      console.log('⚠️  Upsert test failed:', ie.message);
    } else {
      await supabase.from('attendance').delete()
        .match({ group_id: '00000000-0000-0000-0000-000000000000' });
      console.log('✅ Upsert works! Table is ready for the app.');
    }
  }
}

check();
