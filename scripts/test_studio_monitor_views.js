'use strict';
// Pure presentation-contract checks. Root browser acceptance covers actual DOM.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const escape=value=>String(value??'—').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const context={URLSearchParams,Map,Number,Math,Infinity,generation:1,authGeneration:1,esc:escape,
 date:value=>value?new Date(value*1000).toISOString().replace('T',' ').slice(0,19)+' UTC':'—',
 scopedHref:target=>'#'+target,
 intro:(title,body)=>`<h1>${escape(title)}</h1><p>${escape(body)}</p>`,
 link:(kind,id,label)=>`<a href="#${kind}/${encodeURIComponent(id)}">${escape(label||id)}</a>`,
 kv:data=>`<pre>${escape(JSON.stringify(data))}</pre>`};
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(__dirname,'../backend/bmt_backend/admin_ui/monitor_views.js'),'utf8'),context);
vm.runInContext(fs.readFileSync(path.join(__dirname,'../backend/bmt_backend/admin_ui/commerce.js'),'utf8'),context);
const operational={as_of:1800000000,since:100,until:200,players:12,tracks:7,versions:9,pending:2,disabled:1,
 states:{verified:20,failed:1,rejected:3},publications:{pending:3,failed:5000,failed_count_capped:true},
 environment:'fixture',schema:'owned-schema'};
const prepared={telemetry_enabled:true,period_active_players:11,
 coverage:{collection_started_at:100,processed_through:180,latest_receipt_at:190,pending_events:1},
 daily:[{day:'2026-10-09',active_players:7,accepted_races:4,observed:true,current_partial:false},
  {day:'2026-10-10',active_players:null,accepted_races:null,observed:false,current_partial:false},
  {day:'2026-10-11',active_players:99,accepted_races:1,observed:true,current_partial:true}],
 retention:[{cohort_day:'2026-10-01',d7:{mature:true,returned:4,eligible:5}},
  {cohort_day:'2026-10-02',d7:{mature:true,returned:3,eligible:6}},
  {cohort_day:'2026-10-10',d7:{mature:false,returned:null,eligible:12}}],
 funnels:{first_race:{mature:true,cohort_players:10,steps:[{name:'menu_ready',count:8},{name:'race_finished',count:5}]}}};
async function main(){
 let calls=[];context.api=async endpoint=>{calls.push(endpoint);return prepared;};
 const pulse=await context.monitorPulse(operational,new URLSearchParams({since:'100',until:'200'}));
 assert.deepEqual(calls,['product-analytics?since=100&until=200']);
 assert.match(pulse,/Daily observed players<\/span><strong>7<\/strong>/);
 assert.match(pulse,/Active players in this window<\/span><strong>11<\/strong>/);
 assert.match(pulse,/Exact D7 return<\/span><strong>50\.0%<\/strong>/);
 assert.match(pulse,/2026-10-02 cohort · 3 \/ 6/);
 assert.match(pulse,/Crash-free sessions<\/span><strong>Unavailable<\/strong>/);
 assert.equal((pulse.match(/<polyline /g)||[]).length,2,'Unavailable day must break the activity trace');
 assert.match(pulse,/Current partial day/);
 assert.match(pulse,/server fact/);
 assert.match(pulse,/3 explicit publications awaiting verification/);
 assert.match(pulse,/At least 5,000 failed publication requests/);
 assert.match(pulse,/#publications\?state=queued/);
 assert.match(pulse,/#publications\?state=failed/);
 console.log('PASS: Pulse uses one scoped prepared GET, latest complete activity and mature exact-day retention, with broken coverage traces');

 calls=[];context.api=async endpoint=>{calls.push(endpoint);throw Object.assign(Error('Fixture source unavailable'),{status:503});};
 const unavailable=await context.monitorPulse(operational,new URLSearchParams());
 assert.equal(calls.length,1);
 assert.match(unavailable,/Prepared activity source unavailable/);
 assert.match(unavailable,/Registered accounts<\/dt><dd>12/);
 assert.match(unavailable,/Daily observed players<\/span><strong>Not observed/);
 assert.doesNotMatch(unavailable,/Daily observed players<\/span><strong>0/);
 console.log('PASS: Failed product source preserves operational facts and does not turn missing activity into zero');

 context.api=async()=>{throw Object.assign(Error('Aborted'),{name:'AbortError'});};
 await assert.rejects(context.monitorPulse(operational,new URLSearchParams()),{name:'AbortError'});
 context.api=async()=>structuredClone({...prepared,retention:[{cohort_day:'2026-10-10',d7:{mature:false,returned:null,eligible:12}}]});
 const immature=await context.monitorPulse(operational,new URLSearchParams());
 assert.match(immature,/Exact D7 return<\/span><strong>Not mature/);
 assert.doesNotMatch(immature,/Exact D7 return<\/span><strong>0\.0%/);
 console.log('PASS: Abandoned reads propagate cancellation; immature retention is unavailable rather than zero');

 const competition={definition:{id:'competition-1',week_start:100,ends_at:300,vehicle_id:'compact',skill_band:4,
  contract_key:'contract-1',test_population:false,archived:false},slot_count:2,as_of:200,
  roster:[{player_id:'player-1',name:'<img src=x onerror=alert(1)>',is_test_driver:false,disabled:false,
   pre_round_skill:4,points:30,eligible_results:1}],
  results:[{player_id:'player-1',slot:0,run_id:'run-1',seconds:100,ticks:24000,stored_ticks:24000,rank:1,
   rank_from_stored_bests:1,points:30,points_from_stored_bests:30,provenance:'accepted_run',problems:[],manifest:{tick_rate:240}},
   {player_id:'player-1',slot:1,run_id:null,seconds:null,ticks:null,stored_ticks:12000,rank:null,
   rank_from_stored_bests:1,points:0,points_from_stored_bests:30,provenance:'unavailable_or_inconsistent',
   problems:['SOURCE_RUN_UNAVAILABLE'],manifest:{tick_rate:120}}],
  attempt_states:{verified:2,failed:1},attempts_truncated:true,target:null,points_policy:[30,26],limits:['Fixture source limits']};
 const before=JSON.stringify(competition),score=context.monitorCompetition(competition,'rivalry');
 assert.match(score,/Track 2/);assert.doesNotMatch(score,/Track 3/);
 assert.match(score,/100\.000 s/);assert.match(score,/Original accepted run is unavailable/);
 assert.match(score,/First 500 linked submissions only/);assert.match(score,/does not change official scoring/);
 assert.match(score,/&lt;img src=x onerror=alert\(1\)&gt;/);assert.doesNotMatch(score,/<img src=x/);
 assert.equal(JSON.stringify(competition),before,'Rendering must not mutate inspector evidence');
 console.log('PASS: Competition retains actual slot count, accepted timing, source-review reasons, bounds and redacted labels without changing evidence');

 const health={status:'worker_build_mismatch',available_workers:0,active_workers:1,draining_workers:0,
  stopped_workers:0,queue_depth:6,pending_races:2,pending_publications:4,pending_track_validations:1,oldest_age_seconds:121,
  queue_capacity:100,estimated_wait_seconds:null,arrivals_last_5_minutes:3,verified_last_5_minutes:2,
  failed_last_5_minutes:1,rejected_last_5_minutes:0,infrastructure_failure_rate_last_5_minutes:1/3,
  completion_latency_seconds_last_5_minutes:{mean:2,max:4},failures_last_5_minutes:{DEPENDENCY_UNAVAILABLE:1},
  expected_build:{compiler_version:23},worker_builds:[{compiler_version:22}],storage_backend:'gcs',
  storage_free_bytes:null,object_gc_paused:false,backup:{status:'not_configured',age_seconds:null}};
 const reliability=context.monitorReliability(operational,health);
 assert.match(reliability,/Verification availability needs investigation/);
 assert.match(reliability,/Infrastructure failure rate<\/span><strong>33\.3%/);
 assert.match(reliability,/2 races · 4 publication validations/);
 assert.match(reliability,/Unavailable for remote object storage/);
 assert.match(reliability,/completion, including queue time|including queue time/);
 assert.match(reliability,/restore success/);assert.match(reliability,/API expected/);
 assert.doesNotMatch(reliability,/99\.96%|168 ms/);
 console.log('PASS: Reliability exposes real mismatch/queue/failure evidence and keeps uptime, API latency, remote capacity and restore success unavailable');
 calls=[];context.status=value=>`<span>${escape(value)}</span>`;
 context.api=async endpoint=>{calls.push(endpoint);return endpoint==='products'?{editable:false,items:[{id:'slots_1',title:'One slot',price_eur:'1.00',enabled:true,revision:0}]}:
  {limit:25,next_cursor:'opaque-next',items:[{id:'simulation:record',product_id:'slots_1',player_id:'player-1',provider:'simulation',simulated:true,test_adjustment:false,state:'approved',created_at:100,fulfilled_at:101}]};};
 const money=await context.commercePage(new URLSearchParams({provider:'simulation',player_id:'player-1',state:'approved',q:'slots',since:'100',until:'200',cursor:'opaque-page'}));
 assert.deepEqual(calls,['products','purchases?player_id=player-1&state=approved&provider=simulation&cursor=opaque-page&q=slots&since=100&until=200']);
 assert.ok(money.indexOf('Financial source coverage')<money.indexOf('Purchase history'));
 assert.ok(money.indexOf('Purchase history')<money.indexOf('Development catalogue controls'));
 assert.match(money,/Simulation · no payment/);assert.match(money,/Excluded from all spend \/ revenue/);
 assert.match(money,/Verified player spend<\/span><strong>Unavailable/);
 assert.match(money,/Settlement &amp; refunds<\/span><strong>Unavailable/);
 assert.doesNotMatch(money,/data-product=/);
 console.log('PASS: Monetisation preserves scoped record queries, honest financial absence, source-first order and read-only catalogue permission');
 console.log('6 presentation contract checks passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
