
import { supabase } from './src/supabase.js';

async function checkTasks() {
    const { data, error } = await supabase.from('tasks').select('*').limit(1);
    if (data && data.length > 0) {
        console.log('Columns in tasks:', Object.keys(data[0]));
    } else {
        console.log('No data in tasks or error:', error);
    }
}

checkTasks();
