'use strict';
async function rankingWorkspace(params){
 const d=await api('studio/ranking');
 const launch=d.launch_week?date(d.launch_week):'Not configured';
 const fields={state:d.state,launch_week:launch,published_snapshot:d.published_snapshot??'No publication',
  published_week:d.published_week?date(d.published_week):'Unavailable',published_at:d.published_at,
  working_snapshot:d.working_snapshot,branch:d.branch_id,phase:d.phase,mode:d.mode,
  processed_player_key:d.processed_through,archive_part:d.part,
  worker_last_seen:date(d.worker_last_seen_at),last_progress:date(d.progress_at),retrying:d.retrying,error_kind:d.error_kind||'None reported'};
 const incomplete=d.pending&&(!d.worker_last_seen_at||d.as_of-d.worker_last_seen_at>=180);
 return intro('World Ranking operations','Follow publication, settlement progress and accountable corrections.','COMPETITION OPERATIONS')+
 pTabs([['competitions?kind=rivalry','Weekly Rivalry'],['competitions?kind=challenge','Challenges'],['competitions?kind=ranking','World Ranking']],'competitions?kind=ranking',params)+
 (!d.enabled?pNotice('World Ranking launch is not configured','No settlement or publication is expected until a launch is explicitly configured.'):
 d.state==='scheduled'?pNotice('Prospective launch',`Launch is ${launch}. Scheduled inactivity before week close is expected.`):
 incomplete?pNotice('Worker activity is not established','Settlement is pending and its heartbeat is missing or older than three minutes. Inspect the supervised worker and its logs.','warning'):
 d.retrying?pNotice('Settlement is retrying',`Last error category: ${d.error_kind}. The previous published snapshot remains authoritative.`,'warning'):'')+
 `<div class="platform-stats">${pStat('Published generation',pNumber(d.published_snapshot),'Atomic published snapshot')}${pStat('Ranked players',pNumber(d.published_ranked),'Published generation only')}${pStat('Settlement',d.state,d.phase||'No active phase')}${pStat('Worker last seen',d.worker_last_seen_at?Math.max(0,d.as_of-d.worker_last_seen_at)+' s ago':'Unknown','Separate low-priority worker')}</div>`+
 card('Generation and worker evidence',kv(fields)+`<p>The progress cursor is a player key, not a timestamp or a completion percentage. Heartbeats are recorded between batches at most once per 15 seconds. Reads do not execute settlement or infer a healthy worker from a published snapshot.</p><div class="console-actions">${pLink('system/jobs?kind=ranking','Inspect ranking queue',params)}${pLink('alarms','Inspect operations & alarms',params)}${pLink('system/audit?q=world_ranking_correction','Inspect correction audit',params)}</div>`)+
 card('Recent Circuits',pTable(['Circuit','Week starts UTC','Original snapshot','Cars and participation','Pinned tracks'],d.circuits.map(c=>[pNumber(c.id),esc(new Date(c.week_start*1000).toISOString().slice(0,10))+(c.closed?' · closed':' · open'),pNumber(c.original_snapshot),(c.cars||[]).map(v=>`${esc(v.vehicle_id)} · +${((v.participation_bps-10000)/100).toFixed(1)}%${v.weights_locked?'':' · preparing'}`).join('<br>')||'Compact (legacy)',(c.cars?.length?c.cars.flatMap(v=>v.tracks||[]):c.tracks||[]).map(t=>t.version_id?link('tracks',t.version_id,t.name||t.version_id):esc(t.board_id||'Pinned contract')).join('<br>')]))+`${d.circuits_truncated?'<p>Latest 26 circuits shown.</p>':''}`)+
 card('Correction history',pTable(['When','Circuit','Correction / player','Actor','Reason / command'],d.history.map(r=>[esc(date(r.created_at)),pNumber(r.circuit_id),esc(r.kind.replaceAll('_',' '))+' · '+esc(r.vehicle_id||'all cars')+(r.player_id?'<br>'+link('players',r.player_id,'Inspect player'):''),esc(r.actor),`${esc(r.reason)}<small>${esc(r.command_id)}</small>`]))+`<p>${esc(d.history_scope)} ${d.history_truncated?'More history is available in the audit directory.':''}</p>`)+
 (role==='owner'&&d.enabled&&d.circuits.some(c=>c.closed)?card('Preview a correction','<p>A correction excludes one player from a closed circuit or voids that circuit. An accepted correction rebuilds affected generations; it does not change canonical race proofs.</p><button class="btn" id="ranking-correction">Prepare correction</button>'):'');
}

function wireRanking(){
 const button=$('#ranking-correction');if(!button)return;
 button.onclick=async()=>{
  const d=await api('studio/ranking'),commandId=crypto.randomUUID();
  modal(`<h2>Preview ranking correction</h2><form id="ranking-preview"><label>Closed circuit<select name="circuit_id">${d.circuits.filter(c=>c.closed).map(c=>`<option value="${c.id}">${c.id} · ${new Date(c.week_start*1000).toISOString().slice(0,10)}</option>`).join('')}</select></label><label>Car scope<select name="vehicle_id"></select></label><label>Correction<select name="kind"><option value="player">Exclude one player</option><option value="week">Void selected scope</option></select></label><label>Player ID (required for a player exclusion)<input name="player_id" maxlength="36"></label><label>Recorded reason<textarea name="reason" minlength="8" maxlength="500" required></textarea></label><p id="ranking-error" role="alert"></p><div class="console-actions"><button class="btn" type="button" data-close>Cancel</button><button class="btn btn-primary" type="submit">Preview impact</button></div></form>`);
  const circuitSelect=$('#ranking-preview [name=circuit_id]'),carSelect=$('#ranking-preview [name=vehicle_id]');
  const carOptions=()=>{const selected=d.circuits.find(c=>c.id===Number(circuitSelect.value)),cars=selected?.cars?.map(c=>c.vehicle_id)||[];carSelect.innerHTML='<option value="">All cars in the week</option>'+cars.map(car=>`<option value="${esc(car)}">${esc(car)}</option>`).join('');};
  circuitSelect.onchange=carOptions;carOptions();
  const token=dialogToken();
  $('#ranking-preview').onsubmit=async event=>{
   event.preventDefault();const form=new FormData(event.target),submit=event.target.querySelector('[type=submit]');submit.disabled=true;
   const body={command_id:commandId,expected_snapshot:d.published_snapshot||0,circuit_id:Number(form.get('circuit_id')),vehicle_id:form.get('vehicle_id'),player_id:form.get('kind')==='week'?'':form.get('player_id').trim(),void_week:form.get('kind')==='week',reason:form.get('reason').trim()};
   try{
    const preview=await api('studio/ranking/correction-preview',body);if(!dialogIsCurrent(token))return;
    modal(`<h2>Confirm ranking correction</h2><p>${esc(preview.effect)}</p>${kv({kind:preview.kind,circuit:body.circuit_id,car_scope:body.vehicle_id||'All cars in the week',player:body.player_id||'All players in selected scope',expected_published_snapshot:body.expected_snapshot,reason:preview.reason})}<form id="ranking-confirm"><label><input type="checkbox" required> I confirm this audited correction to live ranking records.</label><p id="ranking-error" role="alert"></p><div class="console-actions"><button class="btn" type="button" data-close>Cancel</button><button class="btn btn-primary" type="submit">Apply correction</button></div></form>`);
    const confirmation=dialogToken();
    $('#ranking-confirm').onsubmit=async event=>{
     event.preventDefault();const submit=event.target.querySelector('[type=submit]');submit.disabled=true;
     try{await api('ranking/corrections',body);if(dialogIsCurrent(confirmation)){$('#dialog').close();render();}}
     catch(error){if(dialogIsCurrent(confirmation)){$('#ranking-error').textContent=error.message;submit.disabled=false;}}
    };
   }catch(error){if(dialogIsCurrent(token)){$('#ranking-error').textContent=error.message;submit.disabled=false;}}
  };
 };
}
