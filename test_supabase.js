const url = 'https://vawrdqreibhlfsfvxbpv.supabase.co/rest/v1/rpc/get_mix_salty_foods_data';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhd3JkcXJlaWJobGZzZnZ4YnB2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwNzg1MTAsImV4cCI6MjA4MjY1NDUxMH0.-mAobZK_dc3QOwey3Z8NbrtybWPoPRfBqW_IN0gehl8';

fetch(url, {
    method: 'POST',
    headers: {
        'apikey': key,
        'Authorization': `Bearer ${key}`,
        'Content-Type': 'application/json'
    },
    body: JSON.stringify({
        p_ano: '2026',
        p_mes: '03'
    })
})
.then(res => res.text())
.then(text => console.log(text))
.catch(err => console.error(err));
