import test from 'node:test';
import assert from 'node:assert/strict';
import { refreshProgressModel } from '../src/js/refresh-progress.mjs';

test('progress is based on completed stages and clearly says to wait then reload', () => {
    const m = refreshProgressModel({ status: 'queued', total: 44, completed: 13, failed: 0 });
    assert.equal(m.percent, 29);
    assert.match(m.count, /13 de 44/);
    assert.match(m.detail, /Basta aguardar/);
    assert.match(m.detail, /atualize a página/);
    assert.equal(m.done, false);
});
test('only a successful full run can show completion; failure never becomes 100%', () => {
    assert.equal(refreshProgressModel({status:'succeeded',total:44,completed:44,failed:0}).percent,100);
    assert.equal(refreshProgressModel({status:'processing',total:44,completed:44,failed:0}).percent,99);
    const failed=refreshProgressModel({status:'failed',total:44,completed:43,failed:1});
    assert.equal(failed.done,false); assert.match(failed.detail,/administração/);
    assert.equal(refreshProgressModel(null).visible,false);
});
test('monitor renders actual progress, preserves it on errors and reloads only on request', async () => {
    const children = Object.fromEntries(['title','count','detail','track','fill','check','reload'].map(k=>[k,{style:{},hidden:false,setAttribute(name,value){this[name]=value;},addEventListener(_,fn){this.click=fn;}}]));
    let banner, timer, calls=0, clears=0, reloads=0, reject=false;
    const storage=new Map();
    const root={classList:{contains:()=>false},prepend(node){banner=node;}};
    globalThis.document={hidden:false,getElementById:()=>root,addEventListener(){},createElement(){return {style:{},setAttribute(){},querySelector(sel){return children[sel.slice(6,-1)];}};}};
    globalThis.window={sessionStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v)},location:{reload(){reloads++;}}};
    globalThis.setTimeout=fn=>{timer=fn;return 1;};globalThis.clearTimeout=()=>{};
    let run={status:'queued',total:44,completed:13,failed:0,revision:'run:queued'};
    const client={rpc:async name=>{calls++;assert.equal(name,'get_dashboard_refresh_progress');return reject?{error:{}}:{data:run};}};
    const {startRefreshProgress}=await import('../src/js/refresh-progress.mjs?monitor');
    const monitor=startRefreshProgress(client,{invalidateCache:async()=>{clears++;}});
    await new Promise(resolve=>setImmediate(resolve));
    assert.equal(startRefreshProgress(client),monitor);assert.equal(calls,1);
    assert.equal(banner.hidden,false);assert.equal(children.track['aria-valuenow'],'29');assert.equal(children.reload.hidden,true);
    assert.equal(reloads,0);reject=true;await monitor.check();assert.equal(children.track['aria-valuenow'],'29');assert.match(children.check.textContent,/última informação/);
    reject=false;run={...run,status:'succeeded',completed:44,revision:'run:succeeded'};await monitor.check();
    assert.equal(children.reload.hidden,false);assert.equal(children.track['aria-valuenow'],'100');assert.equal(clears,1);assert.equal(reloads,0);
    await monitor.check();assert.equal(clears,1);await children.reload.click();assert.equal(reloads,1);assert.equal(storage.get('dashboard_refresh_prepared'),'run:succeeded');
    document.hidden=true;const before=calls;await monitor.check();assert.equal(calls,before);
    assert.equal(typeof timer,'function');
});
