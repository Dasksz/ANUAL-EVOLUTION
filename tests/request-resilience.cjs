const assert = require('node:assert/strict');
const createFetch = require('../'+(process.argv[2] || 'js')+'/request-resilience.js');
const host = 'https://example.supabase.co';
const endpoint = host + '/rest/v1/rpc/get_main_dashboard_data';
const read = {method:'POST',headers:{apikey:'public-key',Authorization:'Bearer old'},body:'{"p_ano":"2026"}'};
(async()=>{
 let calls=0, refreshed=0, seen;
 const client={auth:{getSession:async()=>({data:{session:{access_token:'old'}}}),refreshSession:async()=>{refreshed++;await new Promise(r=>setTimeout(r,5));return{data:{session:{access_token:'new'}}};}}};
 const fetch=createFetch(async(_,options)=>{calls++;seen=options;return new Response('{}',{status:new Headers(options.headers).get('Authorization')==='Bearer new'?200:401});},()=>client,host);
 const results=await Promise.all([fetch(endpoint,read),fetch(endpoint,read)]);
 assert(results.every(r=>r.status===200)); assert.equal(refreshed,1);assert.equal(calls,4);
 assert.equal(new Headers(seen.headers).get('apikey'),'public-key');assert.equal(seen.body,read.body);
 for(const url of [host+'/rest/v1/rpc/save_import',host+'/rest/v1/sales',host+'/auth/v1/token']){
  calls=0;const f=createFetch(async()=>{calls++;return new Response('{}',{status:503});},()=>client,host);
  assert.equal((await f(url,read)).status,503);assert.equal(calls,1);
 }
 calls=0;const transient=createFetch(async()=>new Response('{}',{status:++calls===1?503:200}),()=>client,host);
 assert.equal((await transient(endpoint,read)).status,200);assert.equal(calls,2);
 calls=0;const network=createFetch(async()=>{calls++;if(calls===1)throw new TypeError('network');return new Response('{}');},()=>client,host);
 assert.equal((await network(endpoint,read)).status,200);assert.equal(calls,2);
 for(const status of [400,403,500]){
  calls=0;const f=createFetch(async()=>{calls++;return new Response('{"code":"57014"}',{status});},()=>client,host);
  assert.equal((await f(endpoint,read)).status,status);assert.equal(calls,1);
 }
 calls=0;const anonymous=createFetch(async()=>{calls++;return new Response('{}',{status:401});},()=>({auth:{getSession:async()=>({data:{session:null}}),refreshSession:()=>{throw Error('must not refresh');}}}),host);
 assert.equal((await anonymous(endpoint,read)).status,401);assert.equal(calls,1);
 calls=0;const failOnce=createFetch(async()=>{calls++;return new Response('{}',{status:401});},()=>client,host);
 assert.equal((await failOnce(endpoint,read)).status,401);assert.equal(calls,2);
 calls=0;const controller=new AbortController();const cancelled=createFetch(async()=>{calls++;controller.abort();throw new TypeError('network');},()=>client,host);
 await assert.rejects(cancelled(endpoint,{...read,signal:controller.signal}));assert.equal(calls,1);
 console.log('PASS: read-only retry, shared session refresh, headers/body, anonymous/forbidden responses, cancellation and no mutation replay');
})().catch(error=>{console.error(error);process.exitCode=1;});
