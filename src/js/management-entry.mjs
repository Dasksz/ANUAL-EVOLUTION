import supabase from './supabase.js?v=5';
const menu = document.getElementById('profile-dropdown');
const link = document.createElement('a');
link.href = 'gestao.html';
link.textContent = 'Painel de gestão';
link.setAttribute('role', 'menuitem');
link.className = 'hidden w-full text-left px-4 py-2.5 text-sm text-slate-400 hover:bg-orange-500/10 hover:text-orange-500 flex items-center gap-3';
menu?.insertBefore(link, document.getElementById('nav-uploader'));
async function refresh() {
  link.classList.add('hidden');
  const {data, error} = await supabase.rpc('elma_management_access');
  if (!error && data?.allowed) link.classList.remove('hidden');
}
supabase.auth.onAuthStateChange(() => { link.classList.add('hidden'); setTimeout(refresh, 0); });
refresh();
