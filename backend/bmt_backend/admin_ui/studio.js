'use strict';
let studioCurrent=null;
const studioStatusLabels={supported:'Available',partial:'Partial',unavailable:'Unavailable'};
const studioSourceRoutes={race_evidence:'races',track_versions:'tracks',player_support:'players',
  race_bundle:'races',competition_health:'system',operational_counts:'analytics',provider_commerce:'economy',behaviour:'product'};
function studioCoverageTable(items,requirements=false){
 return `<div class="console-table studio-coverage"><table><thead><tr><th scope="col">Source</th><th scope="col">Coverage</th><th scope="col">Evidence and limits</th>${requirements?'<th scope="col">Requirements</th>':''}</tr></thead><tbody>${items.map(item=>`<tr><th scope="row">${esc(item.title||item.key.replaceAll('_',' '))}</th><td><span class="studio-coverage-state ${esc(item.status)}">${esc(studioStatusLabels[item.status]||item.status)}</span></td><td>${esc(item.description)}${studioSourceRoutes[item.key]&&requirements?`<br><a href="${scopedHref(studioSourceRoutes[item.key])}">Open evidence →</a>`:''}</td>${requirements?`<td>${(item.requirement_ids||[]).map(esc).join(' · ')}</td>`:''}</tr>`).join('')}</tbody></table></div>`;
}
async function studioCoverage(){
 const data=await api('studio/capabilities');
 return intro('Data coverage','Available server evidence and the data still needed for the Studio requirements.','CONTROL')+
  `<div class="studio-scope">${esc(data.environment)} · ${esc(data.role)} access · Read-only inspection · ${esc(date(data.as_of))}</div>`+
  card('Connected sources',studioCoverageTable(data.sources,true))+
  card('Observation limits',`<ul class="studio-limits">${data.limitations.map(value=>`<li>${esc(value)}</li>`).join('')}</ul>`);
}
function studioTime(ticks,hz){
 if(!Number.isInteger(ticks)||ticks<=0||!Number.isInteger(hz)||hz<=0)return null;
 const ms=Math.round(ticks*1000/hz),minutes=Math.floor(ms/60000);
 return minutes+':'+String(Math.floor(ms%60000/1000)).padStart(2,'0')+'.'+String(ms%1000).padStart(3,'0');
}
function studioMetric(label,value,id=''){
 return `<div class="metric"><div class="metric-label">${esc(label)}</div><div class="metric-value" ${id?`id="${id}"`:''}>${esc(value)}</div></div>`;
}
async function studioRaceWorkspace(id,params){
 const pageGeneration=generation,data=await api('studio/races/'+encodeURIComponent(id));
 if(pageGeneration!==generation)return '';
 studioCurrent={id,data,pageGeneration};
 const run=data.run,contract=data.contract,timing=data.timing;
 const record={...run,failure_code:run.failure_code||(run.status==='verified'?'No failure':'Not recorded'),ghost_hash:run.ghost_hash||'Not recorded'};
 const human=timing.accepted?studioTime(timing.time_ticks,timing.tick_hz):null;
 const summary=`<div class="metrics four studio-race-metrics">${studioMetric('Verification',run.status)}${studioMetric('Accepted race time',human||'Unavailable','studio-time')}${studioMetric('Verification attempts',run.attempts)}${studioMetric('Current pinned PB',data.personal_best.current?'Yes':'No')}</div>`;
 const links=`<div class="console-actions"><a class="btn" href="${scopedHref('races',params)}">← Race submissions</a>${data.player?link('players',data.player.id,'Open '+data.player.display_name+' →'):''}${contract?.version_id?link('tracks',contract.version_id,'Open exact track version →'):''}<button class="btn btn-primary" id="studio-export">Download evidence bundle</button></div>`;
 const timeline=`<ol class="studio-timeline" id="studio-timeline">${data.lifecycle.map(item=>`<li><time>${esc(date(item.at))}</time><div><strong>${esc(item.event.replaceAll('_',' '))}</strong><p class="console-note">${esc(item.description)}</p></div></li>`).join('')}</ol><p class="console-note">Ticket issuance is not a recorded client race start. The terminal verification timestamp is not the driving finish time.</p>`;
 const laps=timing.lap_ticks?.length?`<div class="console-table"><table id="studio-lap-times"><thead><tr><th scope="col">Lap</th><th scope="col">Accepted time</th><th scope="col">Ticks</th></tr></thead><tbody>${timing.lap_ticks.map((ticks,index)=>`<tr><th scope="row">${index+1}</th><td>${esc(studioTime(ticks,timing.tick_hz)||'Unavailable')}</td><td>${esc(ticks)}</td></tr>`).join('')}</tbody></table></div>`:'<p class="console-note">Accepted lap timing is unavailable for this submission.</p>';
 const timingPanel=`<div id="studio-tick-rate">${kv({pinned_tick_rate:timing.tick_hz,accepted_ticks:timing.time_ticks})}</div>${laps}`;
 const resumes=data.resumes.items.length?`<div class="console-table"><table><thead><tr><th scope="col">Resume</th><th scope="col">Source</th><th scope="col">From / to tick</th><th scope="col">State</th></tr></thead><tbody>${data.resumes.items.map(item=>`<tr><th scope="row">${esc(item.ordinal)}</th><td>${esc(item.source)}</td><td>${esc(item.from_tick)} / ${esc(item.to_tick)}</td><td>${item.refunded?'Refunded':item.settled?'Settled':'Pending'}</td></tr>`).join('')}</tbody></table></div><p class="console-note">${data.resumes.items.length} of ${data.resumes.total} linked receipts.</p>`:'<p class="console-note">No linked resume receipts.</p>';
 const contractPanel=contract?kv({board_id:contract.board_id,track_id:contract.track_id,version_id:contract.version_id,version_number:contract.version_number,track_name:contract.track_name,content_hash:contract.content_hash,vehicle_id:contract.vehicle_id})+`<details><summary>Pinned contract fields</summary>${kv(contract.manifest)}</details>`:'<p class="console-note">Pinned contract is unavailable.</p>';
 return intro('Race evidence · '+id,'Linked server records for this submitted attempt.','OPERATE')+links+summary+
  `<p id="studio-export-status" class="console-note" role="status"></p><div class="console-grid">${card('Submission & verification timeline',timeline)}${card('Accepted timing',timingPanel)}</div><div class="console-grid">${card('Pinned race contract',contractPanel)}${card('Submission record',kv(record)+(data.ticket?`<details><summary>Issued ticket</summary>${kv(data.ticket)}</details>`:''))}</div>`+
  card('Authorized resumes',resumes)+card('Evidence coverage',studioCoverageTable(data.coverage))+
  card('Evidence bundle',`<p class="console-note">Redacted server-record snapshot with a checksum. Client reproduction context has not been captured; this bundle is not a verified reproduction or full replay.</p>${kv({observed_at:data.as_of,checksum:data.checksum})}`);
}
function wireStudio(){
 const button=$('#studio-export');if(!button||!studioCurrent)return;
 const current=studioCurrent,auth=authGeneration;
 button.onclick=async()=>{
  button.disabled=true;$('#studio-export-status').textContent='Preparing redacted evidence…';
  try{
   const data=await api('studio/races/'+encodeURIComponent(current.id)+'?download=true');
   if(current.pageGeneration!==generation||auth!==authGeneration)return;
   const url=URL.createObjectURL(new Blob([JSON.stringify(data,null,2)+'\n'],{type:'application/json'}));
   const anchor=document.createElement('a');anchor.href=url;anchor.download='race-'+current.id+'-evidence.json';anchor.click();
   setTimeout(()=>URL.revokeObjectURL(url),1000);
   $('#studio-export-status').textContent='Evidence bundle downloaded. Reproduction context has not been captured.';
  }catch(error){
   if(current.pageGeneration!==generation||auth!==authGeneration||error.name==='AbortError')return;
   $('#studio-export-status').textContent='Evidence download failed: '+error.message;
  }finally{if(current.pageGeneration===generation&&auth===authGeneration)button.disabled=false;}
 };
}
