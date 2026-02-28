
import { supabase } from './src/supabase.js';

async function listTables() {
    const { data, error } = await supabase.rpc('get_tables'); // common custom RPC if exists
    if (error) {
        // If no RPC, try querying information_schema if enabled (usually not for anon)
        const { data: data2, error: error2 } = await supabase.from('information_schema.tables').select('table_name');
        console.log('Error listing tables via RPC:', error.message);
        console.log('Tables from info schema:', data2 || error2?.message);
    } else {
        console.log('Tables:', data);
    }
}

listTables();
