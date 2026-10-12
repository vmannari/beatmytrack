'use strict';
async function operationsView(section,id,params){
 if(section==='quality'){
  const kinds=['quality_summary','segment_summary','process_exit','discovery','creator'],kind=kinds.includes(params.get('kind'))?params.get('kind'):'quality_summary';
  const query=new URLSearchParams({kind});for(const field of ['since','until'])if(params.has(field))query.set(field,params.get(field));
  const d=await api(kind==='creator'?'creator-health':'quality?'+query);role=d.role;
  const switches='<div class="console-actions">'+[['quality_summary','Frame times'],['segment_summary','Track heatmaps'],['process_exit','Crash / ANR exits'],['discovery','Discovery'],['creator','Creator health']].map(([k,label])=>`<a class="btn" href="${scopedHref('quality?kind='+k,params)}">${label}</a>`).join('')+'</div>';
  if(kind==='creator')return intro('Creator health','Recent immutable versions and current publication state.')+switches+card('Latest versions',`<div class="console-table"><table><thead><tr><th>Version</th><th>Creator</th><th>State</th><th>Published</th></tr></thead><tbody>${d.items.map(r=>`<tr><td>${link('tracks',r.version_id,r.name)}</td><td>${link('players',r.creator_id,r.creator_id)}</td><td>${esc(r.state)}${r.hidden?' · Quarantined':''}</td><td>${esc(date(r.published_at))}</td></tr>`).join('')}</tbody></table></div>${d.truncated?'<p>Latest 100 versions only.</p>':''}`)+card('Coverage',esc(d.coverage));
  let visual='';
  if(kind==='quality_summary'){
   const counts=d.bucket_upper_ms.map((_,i)=>d.items.reduce((sum,r)=>sum+r['b'+i],0)),max=Math.max(1,...counts);
   visual=card('Frame-time histogram',`<div role="img" aria-label="Frame-time bucket counts">${counts.map((v,i)=>`<p>${i===7?'Over 100':(i?d.bucket_upper_ms[i-1]+'–':'0–')+d.bucket_upper_ms[i]} ms: ${v}<span style="display:block;background:#e8c354;height:12px;width:${v/max*100}%"></span></p>`).join('')}</div>`);
  }else if(kind==='segment_summary'&&d.items.length){
   const versions=[...new Set(d.items.map(r=>r.context.track_version_id))],version=versions.includes(params.get('version'))?params.get('version'):versions[0];
   const rows=d.items.filter(r=>r.context.track_version_id===version),minX=Math.min(...rows.map(r=>r.context.cell_x)),minY=Math.min(...rows.map(r=>r.context.cell_y)),width=Math.max(...rows.map(r=>r.context.cell_x))-minX+1,height=Math.max(...rows.map(r=>r.context.cell_y))-minY+1,max=Math.max(1,...rows.map(r=>r.samples));
   visual=card('Sampled presence · 20 m cells','<div class="console-actions">'+versions.map(v=>`<a class="btn" href="${scopedHref('quality?kind=segment_summary&version='+v,params)}">${esc(v)}</a>`).join('')+`</div><svg role="img" aria-label="Sampled track cell heatmap" viewBox="0 0 ${width} ${height}" style="width:100%;height:320px;background:#142434">${rows.map(r=>`<rect x="${r.context.cell_x-minX}" y="${height-1-r.context.cell_y+minY}" width="1" height="1" fill="#e8c354" fill-opacity="${Math.max(.1,r.samples/max)}"><title>Segment ${r.context.segment}, samples ${r.samples}, slow ${r.slow}</title></rect>`).join('')}</svg>`);
  }
  return intro('Client quality & track diagnostics','Prepared client observations; fixed counters and sampled cells.')+switches+visual+card(kind==='discovery'?'Observed discovery exposures / selections':'Observed summaries',`<div class="console-table"><table><thead><tr><th>UTC day</th><th>Context</th><th>${kind==='discovery'?'Exposures':'Reports'}</th><th>${kind==='discovery'?'Selections':'Samples'}</th><th>Slow</th></tr></thead><tbody>${d.items.map(r=>`<tr><td>${esc(date(r.day*86400))}</td><td><pre>${esc(JSON.stringify(r.context,null,2))}</pre></td><td>${r.reports}</td><td>${r.samples}</td><td>${r.slow}</td></tr>`).join('')}</tbody></table></div>${d.truncated?'<p>First 1,000 daily dimensions only.</p>':''}`)+card('Source coverage',kv(d.coverage));
 }
 if(section==='competitions'){
  const kind=params.get('kind')==='challenge'?'challenge':'rivalry';
  const d=await api(id?'competitions/'+kind+'/'+encodeURIComponent(id):'competitions?kind='+kind);
  role=d.role;
  const switches='<div class="console-actions"><a class="btn" href="#competitions?kind=rivalry">Weekly Rivalry</a><a class="btn" href="#competitions?kind=challenge">Challenges</a></div>';
  if(!id)return intro('Competition inspector','Pinned contracts, accepted best results and scoring provenance.')+switches+card('Current records',`<div class="console-table"><table><thead><tr><th>ID</th><th>Ends</th><th>Members</th></tr></thead><tbody>${d.items.map(r=>`<tr><td><a href="#competitions/${esc(r.id)}?kind=${kind}">${esc(r.id)}</a></td><td>${esc(date(r.ends_at))}</td><td>${esc(r.member_count)}</td></tr>`).join('')}</tbody></table></div>${d.has_more?'<p>Additional records exceed this page’s 50-record budget.</p>':''}`);
  return intro(kind==='rivalry'?'Weekly Rivalry inspection':'Challenge inspection','Recomputed from linked accepted evidence. Source inconsistencies remain visible.')+switches+
   card('Pinned definition',kv(d.definition))+card('Roster and pre-round context',`<div class="console-table"><table><thead><tr><th>Driver</th><th>Player type</th><th>Skill at entry</th><th>Attempts used</th><th>Recomputed points</th></tr></thead><tbody>${d.roster.map(r=>`<tr><td>${link('players',r.player_id,r.name)}</td><td>${r.is_test_driver?'Artificial':'Real'}${r.disabled?' · Restricted':''}</td><td>${esc(r.pre_round_skill)}</td><td>${esc(r.attempts_used)}</td><td>${esc(r.points)}</td></tr>`).join('')}</tbody></table></div>`)+
   card('Best-result provenance',`<div class="console-table"><table><thead><tr><th>Slot</th><th>Driver</th><th>Stored / evidence rank</th><th>Stored / evidence points</th><th>Pinned seconds</th><th>Evidence</th><th>Problems</th></tr></thead><tbody>${d.results.map(r=>`<tr><td>${r.slot+1}</td><td>${link('players',r.player_id,d.roster.find(p=>p.player_id===r.player_id)?.name||r.player_id)}</td><td>${esc(r.rank_from_stored_bests)} / ${esc(r.rank)}</td><td>${r.points_from_stored_bests} / ${r.points}</td><td>${esc(r.seconds?.toFixed(3))}</td><td>${r.run_id?link('races',r.run_id,'Inspect race'):esc(r.provenance)}</td><td>${esc(r.problems.join(', ')||'Verified source')}</td></tr>`).join('')}</tbody></table></div>`)+card('Attempt evidence',kv(d.attempt_states)+(d.attempts_truncated?'<p>First 500 linked attempts only.</p>':''))+
   (d.target?card('Exact challenge target',kv(d.target)):'')+card('Inspection limits',`<ul>${d.limits.map(v=>'<li>'+esc(v)+'</li>').join('')}</ul>`);
 }
 const d=await api(id?'cases/'+encodeURIComponent(id):'cases');role=d.role;
 if(!id)return intro('Support cases','Case-linked notes, issue references and recorded workflow decisions.')+
  (role==='owner'?'<button class="btn btn-primary" data-case-action="create">New case</button>':'')+card('Cases',`<div class="console-table"><table><thead><tr><th>Title</th><th>State</th><th>Updated</th></tr></thead><tbody>${d.items.map(r=>`<tr><td><a href="#cases/${esc(r.id)}">${esc(r.title)}</a></td><td>${esc(r.status)}</td><td>${esc(date(r.updated_at))}</td></tr>`).join('')}</tbody></table></div>`);
 const c=d.case;
 return intro(c.title,'Case evidence is append-only; revision checks protect concurrent edits.')+card('Case context',kv(c))+
  (role==='owner'?`<div class="console-actions">${['note','issue','transition',...(c.track_id?['quarantine','restore']:[])].map(a=>`<button class="btn" data-case-action="${a}" data-case-id="${esc(c.id)}" data-case-revision="${c.revision}">${{note:'Add note',issue:'Link issue',transition:'Change state',quarantine:'Quarantine track',restore:'Restore track'}[a]}</button>`).join('')}</div>`:'')+
  card('Activity',`<ol>${d.events.map(e=>`<li><b>${esc(e.kind)}</b> · ${esc(date(e.created_at))}<pre style="white-space:pre-wrap">${esc(JSON.stringify(e.detail,null,2))}</pre></li>`).join('')}</ol>${d.history_truncated?'<p>Latest 100 events only.</p>':''}`)+card('Coverage',kv(d.coverage));
}
document.addEventListener('click',event=>{
 const target=event.target.closest('[data-case-action]');if(!target||role!=='owner')return;
 const action=target.dataset.caseAction,auth=authGeneration,credential=key,view=generation;
 const dialog=$('#dialog');
 dialog.innerHTML=`<form class="console-padding"><h3>${action==='create'?'New case':action==='transition'?'Case transition':'Case evidence'}</h3>${action==='transition'?'<label>State<select name="status"><option>investigating</option><option>resolved</option><option>appealed</option><option>open</option></select></label>':''}<label>${action==='create'?'Title':action==='issue'?'Issue reference':'Note / reason'}<textarea name="text" maxlength="${action==='create'?160:2000}" required></textarea></label><p class="console-note">Keep credentials, purchase tokens and private keys out of case evidence.</p><p class="console-error" id="case-error"></p><div class="console-actions"><button class="btn" type="button" id="case-cancel">Cancel</button><button class="btn btn-primary">Save</button></div></form>`;
 if(action==='create')dialog.querySelector('textarea').closest('label').insertAdjacentHTML('afterend','<label>Player ID (optional)<input name="player_id" maxlength="36"></label><label>Track ID (optional)<input name="track_id" maxlength="36"></label>');
 dialog.showModal();dialog.addEventListener('close',()=>{if(target.isConnected)target.focus();},{once:true});$('#case-cancel').onclick=()=>dialog.close();
 const command=crypto.randomUUID();dialog.querySelector('form').onsubmit=async ev=>{
  ev.preventDefault();if(auth!==authGeneration||credential!==key||view!==generation)return;
  const form=new FormData(ev.target),body=action==='create'?{command_id:command,title:form.get('text')}:{command_id:command,expected_revision:Number(target.dataset.caseRevision),kind:action,text:form.get('text'),...(action==='transition'?{status:form.get('status')}:{})};
  if(action==='create')for(const field of ['player_id','track_id'])if(form.get(field)?.trim())body[field]=form.get(field).trim();
  const save=ev.target.querySelector('button:not([type="button"])');save.disabled=true;
  try{const d=await api(action==='create'?'cases':'cases/'+target.dataset.caseId+'/events',body);if(auth!==authGeneration||view!==generation)return;dialog.close();location.hash='cases/'+d.id;await render();}
  catch(e){if(auth===authGeneration&&view===generation&&dialog.open){$('#case-error').textContent=e.message;save.disabled=false;}}
 };
});
