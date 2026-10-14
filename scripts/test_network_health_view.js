'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const context={URLSearchParams,Number,Math,Set,role:'',esc:value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),date:value=>String(value),intro:(title,body)=>`<h1>${title}</h1><p>${body}</p>`,scopedHref:target=>'#'+target};
vm.createContext(context);
for(const name of ['monitor.js','network.js'])vm.runInContext(fs.readFileSync(path.join(__dirname,'../backend/bmt_backend/admin_ui',name),'utf8'),context);
async function main(){
 const calls=[];
 context.api=async endpoint=>{calls.push(endpoint);return {role:'analyst',items:[],totals:{},failures:[],categories:['profile','score_upload'],buckets:{error_buckets:Array(16).fill(0)},error_types:['none','cancelled','dns','connect','tls','timeout','connection','body_limit','redirect','invalid_response','encoding','local','http_4xx','throttled','http_5xx','http_other'],collection:{enabled:true,latest_summary_at:null,processor_observed_at:null},coverage:'Client observations',latency_bucket_upper_ms:[25,50,100,250,500,1000,5000,null],upload_age_bucket_upper_seconds:[1,5,15,60,300,3600,86400,null]};};
 const page=await context.monitorQualityView(new URLSearchParams({tab:'network',since:'10',until:'20',category:'profile',device_model:'<img src=x>',build_id:'unknown-build'}));
 assert.deepEqual(calls,['network-health?since=10&until=20&build_id=unknown-build&category=profile&device_model=%3Cimg+src%3Dx%3E']);
 assert.match(page,/No client network summaries/);assert.match(page,/&lt;img src=x&gt;/);assert.doesNotMatch(page,/<img src=x>/);
 assert.match(page,/No observed denominator/);assert.match(page,/unverified hints/);
 assert.equal(context.networkRange([1,0,0,0,0,0,0,0],[25,50,100,250,500,1000,5000,null]),'0-25 ms');
 assert.equal(context.networkRange([0,0,0,0,0,0,0,1],[25,50,100,250,500,1000,5000,null]),'Over 5000 ms');
 assert.equal(context.networkRange(Array(8).fill(0),[25,50,100,250,500,1000,5000,null]),'Not observed');
 console.log('NETWORK_VIEW: scoped single GET, empty coverage, escaped selectors and exact bucket labels passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
