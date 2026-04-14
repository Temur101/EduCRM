
import { supabase } from './src/supabase.js';

async function checkTables() {
    const tables = ['leads', 'lead_stages', 'boards', 'tasks'];
    for (const table of tables) {
        const { error } = await supabase.from(table).select('*').limit(1);
        console.log(`Table ${table}: ${error ? 'Error (' + error.message + ')' : 'Exists'}`);
    }
}

checkTables();
