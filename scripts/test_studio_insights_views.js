'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const escape=value=>String(value??'Unavailable').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const context={URLSearchParams,Map,Number,Math,generation:1,authGeneration:1,esc:escape,
 date:value=>value?'UTC '+value:'Unavailable',scopedHref:target=>'#'+target,
 intro:(title,body)=>`<h1>${escape(title)}</h1><p>${escape(body)}</p>`};
vm.createContext(context);
for(const file of ['monitor_views.js','insights.js'])vm.runInContext(fs.readFileSync(path.join(__dirname,'../backend/bmt_backend/admin_ui',file),'utf8'),context);
const operational={as_of:200,since:100,until:200,pending:4,states:{verified:8,rejected:1,failed:1,queued:99}};
const prepared={telemetry_enabled:true,period_active_players:7,daily:[],coverage:{collection_started_at:100},
 retention:[{cohort_day:'mature',d7:{mature:true,returned:2,eligible:5}},{cohort_day:'immature',d7:{mature:false,returned:0,eligible:50}}],
 funnels:{first_race:{mature:true,steps:[{name:'menu_ready',count:10},{name:'race_started',count:8},{name:'race_finished',count:3}]}}};
async function main(){
 let calls=[];context.api=async target=>{calls.push(target);return target==='alarms'?{checks:8,as_of:200,items:[],unknown_checks:0}:prepared;};
 const html=await context.insightOverview(operational,new URLSearchParams({since:'100',until:'200'}));
 assert.deepEqual(calls,['product-analytics?since=100&until=200','alarms']);
 assert.match(html,/80\.0%/);assert.match(html,/8 \/ 10 terminal submissions/);
 assert.match(html,/5 of 8 cohort players did not reach race finish after race start/);
 assert.match(html,/40\.0% returned on day seven/);assert.doesNotMatch(html,/immature cohort/);
 assert.match(html,/No configured alarm is firing/);
 console.log('PASS scoped findings use terminal outcomes, largest ordered cohort loss and mature exact D7 denominators');
 context.api=async target=>target==='alarms'?{checks:8,unknown_checks:6,items:[]}:{...prepared,funnels:{first_race:{mature:false,steps:prepared.funnels.first_race.steps}}};
 const missing=await context.insightOverview(operational,new URLSearchParams());
 assert.match(missing,/Some checks could not be completed/);assert.doesNotMatch(missing,/No configured alarm is firing|Largest observed first-race drop-off/);
 console.log('PASS unavailable checks and immature cohorts do not imply healthy service or mature product findings');
 context.api=async target=>{if(target==='alarms')throw Error('Source <script> failed');return prepared;};
 const failure=await context.insightOverview(operational,new URLSearchParams());
 assert.match(failure,/Alarm checks could not be loaded/);assert.match(failure,/Source &lt;script&gt; failed/);
 assert.doesNotMatch(failure,/No configured alarm is firing|<script>/);
 context.api=async()=>{throw Object.assign(Error('Aborted'),{name:'AbortError'});};
 await assert.rejects(context.insightOverview(operational,new URLSearchParams()),{name:'AbortError'});
 console.log('PASS source failure is explicit and escaped; cancelled reads preserve navigation fences');
 const items=[{key:'warning',active:true,severity:'warning',status:'open'},
  {key:'critical',active:true,severity:'critical',status:'acknowledged'},
  {key:'recovered',active:false,severity:'critical',status:'recovered'}];
 assert.deepEqual(Array.from(context.orderedAlarms(items),item=>item.key),['critical','warning','recovered']);
 assert.equal(items[0].key,'warning');
 console.log('PASS active critical conditions lead warnings even after acknowledgement; evidence order is not mutated');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
