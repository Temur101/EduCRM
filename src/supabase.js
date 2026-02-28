import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://derdfzohcuftfzvazsub.supabase.co'
const supabaseKey = 'sb_publishable_r0pYLxnopHTx3w3LnzmV8g_t1rxiB-w'
export const supabase = createClient(supabaseUrl, supabaseKey)
