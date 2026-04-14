
import { supabase } from './src/supabase.js';

async function checkBoards() {
    const { data, error } = await supabase.from('boards').select('*').limit(1);
    if (data && data.length > 0) {
        console.log('Columns in boards:', Object.keys(data[0]));
    } else {
        console.log('No data in boards or error:', error);
    }
}

checkBoards();
