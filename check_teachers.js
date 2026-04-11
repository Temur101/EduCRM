
import { supabase } from './src/supabase.js';

async function check() {
    const { error } = await supabase.from('teachers').select('*').limit(1);
    if (error) {
        console.log('Teachers table does not exist or error:', error.message);
    } else {
        console.log('Teachers table exists');
    }
}
check();
