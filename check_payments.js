import { createClient } from '@supabase/supabase-js'
const supabase = createClient(
  'https://derdfzohcuftfzvazsub.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlcmRmem9oY3VmdGZ6dmF6c3ViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwMzMzMzcsImV4cCI6MjA4NzYwOTMzN30.weUFnPj8gdmADy6vDZveFDp4XzFkqOwbgfiq20YehUs'
)
const { data, error } = await supabase.from('payments').select('*').limit(2)
if (error) console.error(error.message)
else {
  console.log('Columns:', Object.keys(data[0] || {}))
  console.log('Sample:', JSON.stringify(data[0], null, 2))
}
