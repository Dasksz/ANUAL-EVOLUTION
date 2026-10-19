const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../src/js/app.js'),'utf8');
const code=source.slice(source.indexOf('    async function checkDataVersion()'),source.indexOf('    function getCurrentFilters()'));
test('client ownership or goal revision invalidates both caches before the next read',async()=>{
 let local='old',server='new',salesClears=0,goalClears=0;
 const ctx=vm.createContext({supabase:{rpc:async()=>({data:server})},localStorage:{getItem:()=>local,setItem:(_,value)=>{local=value}},initDB:async()=>({clear:async()=>{salesClears++}}),STORE_NAME:'data',clearGoalsQueryCache:()=>{goalClears++},AppLog:{log(){},warn(){},error(){}}});
 vm.runInContext(code,ctx);
 await ctx.checkDataVersion();assert.equal(local,'new');assert.equal(salesClears,1);assert.equal(goalClears,1);
 await ctx.checkDataVersion();assert.equal(goalClears,1);
 server='portfolio-updated';await ctx.checkDataVersion();assert.equal(salesClears,2);assert.equal(goalClears,2);
});
