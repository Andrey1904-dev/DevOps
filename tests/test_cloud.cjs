/* Mocked REST contract tests, not a real email login or browser acceptance. */
const assert=require('node:assert/strict');
const fs=require('node:fs');const vm=require('node:vm');const {webcrypto}=require('node:crypto');
const {spawnSync}=require('node:child_process');
const r=spawnSync('python3',['-B','-c','import json; from content import public_catalog; from academy import initial_state; print(json.dumps(dict(catalog=public_catalog(),state=initial_state())))'],{encoding:'utf8'});
assert.equal(r.status,0,r.stderr);const fixture=JSON.parse(r.stdout);
const storage=new Map(), handlers={}, elements={'#app':{innerHTML:''},'#notice':{innerHTML:''},'.topbar .pill':{},'.sidebar-bottom':{}};
let calls=[],networkFailure=false,conflict=false,remoteState=structuredClone(fixture.state),rev=0;
const ctx={console,URL,URLSearchParams,TextEncoder,Date,crypto:webcrypto,btoa:s=>Buffer.from(s,'binary').toString('base64'),
 location:{href:'https://andrey1904-dev.github.io/DevOps/#home',origin:'https://andrey1904-dev.github.io',pathname:'/DevOps/',hash:'#home'},
 history:{replaceState:()=>{}},
 sessionStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v),removeItem:k=>storage.delete(k)},
 localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v),removeItem:k=>storage.delete(k)},
 document:{querySelector:k=>elements[k],addEventListener:(k,f)=>handlers[k]=f},window:{addEventListener:()=>{}},
 fetch:async(url,opts={})=>{
  calls.push({url,opts});if(networkFailure)throw new Error('offline');
  let data={},status=200;
  if(url==='./catalog.json')return {ok:true,json:async()=>fixture.catalog};
  if(url.includes('grant_type=password'))data={access_token:'synthetic_access',refresh_token:'synthetic_refresh',expires_in:3600,user:{id:'synthetic_user'}};
  else if(url.includes('grant_type=refresh_token'))data={access_token:'synthetic_refreshed',refresh_token:'synthetic_refresh2',expires_in:3600,user:{id:'synthetic_user'}};
  else if(url.endsWith('/rpc/academy_load'))data={state:remoteState,revision:rev};
  else if(url.endsWith('/rpc/academy_action')){
   const p=JSON.parse(opts.body);if(conflict||p.expected_revision!==rev){status=409;data={code:'40001',message:'stale revision'};}
   else{remoteState.notes.push({text:p.payload.text,at:new Date().toISOString()});rev++;data={revision:rev};}
  }
  return {ok:status===200,status,text:async()=>JSON.stringify(data)};
 }};
vm.createContext(ctx);vm.runInContext(fs.readFileSync('cloud/config.js','utf8'),ctx);vm.runInContext(fs.readFileSync('cloud/client.js','utf8'),ctx);
const cloud=ctx.AcademyCloud;
(async()=>{
 let n=0;const check=(ok)=>{assert.ok(ok);n++;};
 await cloud.mount(()=>{},()=>{});check(elements['#app'].innerHTML.includes('Вход для приглашённого'));
 await cloud.api('/api/catalog');check(cloud.summary(fixture.state).completed===0);
 await assert.rejects(()=>cloud.api('/api/state'),/Войдите/);n++;
 // Execute the actual login handler against mocked GoTrue, never a real account.
 ctx.FormData=class {constructor(){return new Map([['email','synthetic@example.invalid'],['password','synthetic-only']]);}};
 const form={dataset:{auth:'password'},querySelector:()=>({disabled:false,isConnected:false}),reset:()=>{}};
 await handlers.submit({target:{closest:()=>form},preventDefault:()=>{}});
 const loaded=await cloud.api('/api/state');check(loaded.state.attempts.length===0);
 await cloud.api('/api/action/note',{text:'synthetic note'});await cloud.api('/api/state');check(remoteState.notes.length===1);
 const exported=await cloud.api('/api/export');check(exported.state.notes.length===1&&!('csrf' in exported));
 for(const role of Object.keys(fixture.catalog.mentors)){
  const p=await cloud.api('/api/mentor-context?mentor='+role);check(p.prompt.includes(role)&&p.prompt.includes('недоверенные данные'));
 }
 conflict=true;await assert.rejects(()=>cloud.api('/api/action/note',{text:'not saved'}),/stale/);n++;conflict=false;check(remoteState.notes.length===1);
 networkFailure=true;await assert.rejects(()=>cloud.api('/api/state'),/Нет связи/);n++;networkFailure=false;
 // Restore a prior browser session; no new password call on remount.
 const before=calls.filter(x=>x.url.includes('grant_type=password')).length;
 await cloud.mount(()=>{},()=>{});await cloud.api('/api/state');check(calls.filter(x=>x.url.includes('grant_type=password')).length===before);
 let key=[...storage.keys()].find(k=>k.endsWith(':session:v1'));let saved=JSON.parse(storage.get(key));saved.expires_at=0;storage.set(key,JSON.stringify(saved));
 await cloud.mount(()=>{},()=>{});check(calls.some(x=>x.url.includes('grant_type=refresh_token')));
 ctx.FormData=class {constructor(){return new Map([['email','synthetic@example.invalid']]);}};
 await handlers.submit({target:{closest:()=>({...form,dataset:{auth:'magic'}})},preventDefault:()=>{}});
 const otp=calls.find(x=>x.url.includes('/auth/v1/otp?'));const payload=JSON.parse(otp.opts.body);
 check(payload.create_user===false&&payload.code_challenge_method==='s256'&&!payload.code_verifier);
 check(otp.url.includes(encodeURIComponent('https://andrey1904-dev.github.io/DevOps/')));
 await handlers.click({target:{closest:()=>true}});check(!storage.has(key));check(elements['#app'].innerHTML.includes('Вход для приглашённого'));
 check(calls.filter(x=>x.url.startsWith('https:')).every(x=>x.url.startsWith('https://bkufrpbjgtpwtvutsvnh.supabase.co/')));
 console.log(JSON.stringify({cloud_contract_checks:n,result:'passed',real_auth_login:false,visual_check:false}));
})().catch(e=>{console.error(e);process.exitCode=1;});
