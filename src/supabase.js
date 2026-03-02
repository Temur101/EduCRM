import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://derdfzohcuftfzvazsub.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlcmRmem9oY3VmdGZ6dmF6c3ViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwMzMzMzcsImV4cCI6MjA4NzYwOTMzN30.weUFnPj8gdmADy6vDZveFDp4XzFkqOwbgfiq20YehUs'
export const supabase = createClient(supabaseUrl, supabaseKey)
