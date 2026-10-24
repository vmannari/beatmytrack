'use strict';
const $=s=>document.querySelector(s), esc=v=>String(v??'—').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let key='', role='', generation=0, reporting=null, authGeneration=0, readController=null;
let dialogGeneration=0, dialogOpener=null, lastRenderedRoute='';
const sections=[['overview','Overview','\u25eb','START HERE'],['alarms','Operations & alarms','!',''],
 ['product','Player behaviour','\u2197','UNDERSTAND'],['quality','Game quality','\u2301',''],['economy','Monetisation','\u25a3',''],
 ['tracks','Content & competitions','\u25b1','INVESTIGATE'],['cases','Player support','\u25c7',''],
 ['studio','Administration','\u25a4','MANAGE']];
const titles={...Object.fromEntries(sections.map(x=>[x[0],x[1]])),players:'Players',races:'Race evidence',publications:'Publications',competitions:'Competitions',system:'Service health'};
const date=v=>v?new Date(v*1000).toISOString().replace('T',' ').slice(0,19)+' UTC':'—';
const status=v=>`<span class="console-state ${['failed','rejected','queued','disabled','hidden'].includes(String(v))?'warn':''}">${esc(v)}</span>`;
function intro(title,sub,section='OPERATE'){return `<header class="console-intro"><small>${esc(section)}</small><h1>${esc(title)}</h1><p>${esc(sub)}</p></header>`;}
function card(title,body){return `<section class="card"><div class="card-head"><h3>${esc(title)}</h3></div><div class="console-padding">${body}</div></section>`;}
function scopedHref(target,params=null){
 const [path,qs]=target.split('?'),query=new URLSearchParams(qs);
 const scope=params||reporting;
 if(!query.has('all')&&scope){
  for(const field of ['since','until']){const value=scope instanceof URLSearchParams?scope.get(field):scope[field];if(value!=null&&!query.has(field))query.set(field,value);}
 }
 return '#'+path+(query.size?'?'+query:'');
}
function link(kind,id,label){return `<a href="${scopedHref(kind+'/'+encodeURIComponent(id))}">${esc(label||id)}</a>`;}
async function api(path,body,options={}){
 const credential=key, auth=authGeneration;
 const res=await fetch('/v1/admin/'+path,{headers:{Authorization:'Bearer '+credential,...(body?{'Content-Type':'application/json'}:{})},...(body?{method:'POST',body:JSON.stringify(body)}:{signal:options.signal||readController?.signal})});
 let data;try{data=await res.json();}catch{throw Error('The backend returned an unreadable response. Retry this request.');}
 if(auth!==authGeneration||credential!==key)throw new DOMException('Administrative access changed.','AbortError');
 if(!res.ok){const message=typeof data.detail==='string'?data.detail:data.detail?.code?data.detail.code+(data.detail.field?' · '+data.detail.field:''):'Request failed';if(res.status===401){clearAccess();login(message);}const error=Error(message);error.status=res.status;throw error;}
 return data;
}
function login(message=''){
 generation++;readController?.abort();
 $('#main').removeAttribute('aria-busy');
 $('#main').innerHTML=`<div class="console-login">${intro('BMT Studio','Sign in with a dedicated administrator credential.')}<form id="login" class="card console-padding"><label for="key">Staff identity token or legacy key</label><input id="key" type="password" autocomplete="off" required minlength="32"><p class="console-note">Credentials remain in this tab’s memory. Lock or reload to clear access. Game sign-in credentials do not grant console access.</p><div class="console-actions"><button class="btn btn-primary">Connect</button></div><p id="login-error" class="console-error" ${message?'':'hidden'}>${esc(message)}</p></form></div>`;
 $('#login').onsubmit=async e=>{e.preventDefault();authGeneration++;key=$('#key').value;await render();};
}
function tabs(items,current){return `<div class="tabs">${items.map(([id,label])=>`<a class="tab ${id===current?'active':''}" href="#${id}">${esc(label)}</a>`).join('')}</div>`;}
function metric(name,value,target,note){return `<a href="#${target}" class="metric"><div class="metric-label">${esc(name)} →</div><div class="metric-value">${esc(value)}</div><div class="metric-meta">${esc(note)}</div></a>`;}
function periodTarget(target,d){return target+(target.includes('?')?'&':'?')+'since='+d.since+'&until='+d.until;}
function rangeParams(params){const result=new URLSearchParams(params);if(result.has('all')){result.delete('since');result.delete('until');}else if(!result.has('since')&&reporting){result.set('since',reporting.since);result.set('until',reporting.until);}return result;}
function reportingDates(){
 if(!reporting)return;
 const day=value=>new Date(value*1000).toISOString().slice(0,10);
 modal(`<h2>Reporting dates · UTC</h2><form id="reporting-dates"><label>From<input id="report-from" type="date" value="${day(reporting.since)}" required></label><label>Through<input id="report-through" type="date" value="${day(reporting.until-1)}" required></label><p id="dates-error" class="console-error" hidden></p><div class="console-actions"><button class="btn" type="button" data-close>Cancel</button><button class="btn btn-primary">Apply dates</button></div></form>`);
 $('#reporting-dates').onsubmit=event=>{event.preventDefault();const since=Date.parse($('#report-from').value+'T00:00:00Z')/1000,until=Date.parse($('#report-through').value+'T00:00:00Z')/1000+86400;if(!Number.isFinite(since)||!Number.isFinite(until)||since<0||until<=since||until-since>90*86400){$('#dates-error').hidden=false;$('#dates-error').textContent='Choose a range of 1–90 calendar days.';return;}const [path,qs]=location.hash.slice(1).split('?'),params=new URLSearchParams(qs);for(const name of ['all','offset','cursor'])params.delete(name);params.set('since',since);params.set('until',until);$('#days').value='custom';$('#dialog').close();location.hash=path+'?'+params;};
}

function playerType(value){return value===true?'Artificial':value===false?'Real':'Unavailable';}
const columns={players:['display_name','id','is_test_driver','disabled','created_at'],tracks:['name','state','hidden','number','rating_count','owner_id'],races:['id','player_id','status','time_ticks','attempts','created_at'],jobs:['id','status','attempts','failure_code','created_at'],audit:['action','entity_id','actor','reason','created_at'],grants:['id','player_id','source','quantity','created_at']};
function cell(kind,k,v,row){if(k==='is_test_driver')return esc(playerType(v));if(k==='created_at')return esc(date(v));if(k==='id'||k==='name'||k==='display_name')return link(kind,row.id,v);if(k==='player_id'||k==='owner_id')return link('players',v);if(k==='status'||k==='state')return status(v);if(k==='disabled')return status(row.deleted_at?'removed':v?'disabled':'active');if(k==='hidden')return status(v?'hidden':'visible');return esc(v);}
async function listing(kind,params){
 const query=new URLSearchParams({q:params.get('q')||'',state:params.get('state')||''});
 for(const name of ['since','until','failure_code','cursor','offset'])if(params.has(name))query.set(name,params.get(name));
 const d=await api('entities/'+kind+'?'+query),cols=columns[kind],states=kind==='players'?['active','disabled','removed']:kind==='tracks'?['draft','tested','published']:['queued','verifying','verified','rejected','failed'];
 return `<section class="card"><form id="filters" class="console-toolbar"><label for="filter">Search</label><input id="filter" name="q" value="${esc(query.get('q'))}" placeholder="Name or stable identifier">${['players','tracks','races','jobs'].includes(kind)?`<label for="state">State</label><select name="state" id="state"><option value="">All states</option>${states.map(s=>`<option ${s===query.get('state')?'selected':''}>${s}</option>`).join('')}</select>`:''}<button class="btn">Apply filters</button></form><div class="console-table"><table><thead><tr>${cols.map(c=>`<th>${esc(c==='is_test_driver'?'Player type':c.replaceAll('_',' '))}</th>`).join('')}</tr></thead><tbody>${d.items.map(row=>`<tr>${cols.map(k=>`<td>${cell(kind,k,row[k],row)}</td>`).join('')}</tr>`).join('')}</tbody></table>${!d.items.length?'<p class="console-empty">No matching records.</p>':''}</div><div class="console-pager"><span>${d.items.length?d.offset+1:0}–${d.offset+d.items.length} · ${d.items.length} records shown</span><button class="btn" data-page-cursor="${esc(d.previous_cursor||'')}" ${d.previous_cursor?'':'disabled'}>Previous</button><button class="btn" data-page-cursor="${esc(d.next_cursor||'')}" ${d.next_cursor?'':'disabled'}>Next</button></div></section>`;
}
function routeMap(preview){
 const points=(preview.points||[]).filter(p=>Array.isArray(p)&&p.length>=2&&Number.isFinite(p[0])&&Number.isFinite(p[1]));
 if(points.length<2)return '<p class="console-note">Route preview unavailable.</p>';
 const xs=points.map(p=>p[0]),ys=points.map(p=>p[1]),minX=Math.min(...xs),minY=Math.min(...ys),scale=440/Math.max(1,Math.max(...xs)-minX,Math.max(...ys)-minY);
 const coordinates=points.map(p=>`${30+(p[0]-minX)*scale},${30+(p[1]-minY)*scale}`).join(' ');
 return `<svg class="console-map" viewBox="0 0 500 500" role="img" aria-label="Stored lap route schematic"><rect width="500" height="500" fill="#e5ece4"/><polyline points="${coordinates}" fill="none" stroke="#82978a" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/><polyline points="${coordinates}" fill="none" stroke="#f4f3e7" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/></svg><p class="console-note">${esc(preview.theme)} &middot; Stored route schematic, not road geometry or elevation.</p>`;
}
function kv(data){return `<dl>${Object.entries(data).map(([k,v])=>`<div class="console-kv"><dt>${esc(k.replaceAll('_',' '))}</dt><dd>${v==null?'Unavailable':k.endsWith('_at')||k.endsWith('_until')?esc(date(v)):typeof v==='object'?`<pre>${esc(JSON.stringify(v,null,2))}</pre>`:esc(v)}</dd></div>`).join('')}</dl>`;}
async function inspect(kind,id,params){if(kind==='players')return supportWorkspace(id,params);if(kind==='races')return studioRaceWorkspace(id,params);const d=await api(`entities/${kind}/${encodeURIComponent(id)}`);let actions='';if(role==='owner'&&['players','tracks'].includes(kind)){const value=kind==='players'?d.disabled:d.hidden;actions=`<button class="btn" id="command" data-kind="${kind}" data-id="${esc(kind==='players'?d.id:d.track_id)}" data-value="${value}">${kind==='players'?(value?'Restore account':'Restrict account'):(value?'Show track':'Hide track')}</button>`;}
const manifest=d.manifest,recent=d.recent_races,preview=d.route_preview,entitlements=d.entitlements;delete d.entitlements;delete d.manifest;delete d.recent_races;delete d.route_preview;return intro(d.display_name||d.name||`${kind==='races'?'Race evidence':'Record'} · ${id}`,`Canonical ${kind} record · ${id}`)+`<div class="console-actions"><a class="btn" href="${scopedHref(kind,params)}">← Back to list</a>${actions}${d.player_id?link('players',d.player_id,'Open player →'):''}${d.version_id?link('tracks',d.version_id,'Open track version →'):''}${d.owner_id?link('players',d.owner_id,'Open creator →'):''}</div><div class="console-grid">${card('Record',(preview?routeMap(preview):'')+kv(d))}${card(manifest?'Pinned eligibility / content manifest':'Record context',manifest?kv(manifest):'<p class="console-note">Identity subjects and session tokens are withheld. Permanent resume balance excludes the daily free resume. Account restrictions revoke existing player sessions. Account removal erases identity and private data while retaining redacted tracks and historical standings. Privacy exports are not configured.</p>')}</div>${kind==='players'?playerCommerce(d.id,entitlements):''}${recent?card('Recent race timeline',recent.length?recent.map(r=>`<div class="console-kv"><dt>${esc(date(r.created_at))}</dt><dd>${link('races',r.id)} ${status(r.status)}</dd></div>`).join(''):'<p class="console-empty">No submitted races.</p>'):''}`;}
function unavailable(title,why){return card(title,`<div class="console-empty"><h3>Not available</h3><p class="console-note">${esc(why)}</p></div>`);}
async function systemHealth(){const h=await api('competition-health');return card('Verified competition',kv({status:h.status,available_workers:h.available_workers,active_workers:h.active_workers,draining_workers:h.draining_workers,stopped_workers:h.stopped_workers,queue_depth:h.queue_depth,queue_capacity:h.queue_capacity,oldest_age_seconds:h.oldest_age_seconds,estimated_wait_seconds:h.estimated_wait_seconds,arrivals_last_5_minutes:h.arrivals_last_5_minutes,verified_last_5_minutes:h.verified_last_5_minutes,pending_track_validations:h.pending_track_validations,infrastructure_failure_rate:h.infrastructure_failure_rate_last_5_minutes,completion_latency_seconds:h.completion_latency_seconds_last_5_minutes,worker_queue_wait_seconds:h.worker_queue_wait_seconds,worker_verification_seconds:h.worker_verification_seconds,failures_last_5_minutes:h.failures_last_5_minutes,storage_backend:h.storage_backend,storage_free_gib:h.storage_free_bytes==null?null:Math.round(h.storage_free_bytes/1073741824*10)/10,backup:h.backup})+`<details><summary>Build compatibility</summary>${kv({expected_build:h.expected_build,worker_builds:h.worker_builds})}</details>`)+card('Observation limits','<p class="console-note">Throughput and latency use the last five minutes. Cloud storage has no local free-capacity measurement. The backup marker does not observe provider backups or establish restore success.</p>');}

async function render(){
 if(!key){login();return;}
 const ticket=++generation;
 readController?.abort();readController=new AbortController();
 if($('#dialog').open)$('#dialog').close();
 const raw=location.hash.slice(1)||'overview',[path,qs]=raw.split('?'),[section,id]=path.split('/');
 let params=new URLSearchParams(qs);
 $('#main').setAttribute('aria-busy','true');
 $('#main').innerHTML='<p class="console-empty" role="status">Loading current records…</p>';
 $('#freshness').textContent='Loading evidence…';
 document.querySelectorAll('.console-nav').forEach(a=>{
  const group={system:'alarms',analytics:'alarms',publications:'tracks',competitions:'tracks',players:'cases',races:'cases',live:'studio'};const active=a.dataset.route===(group[section]||section);a.classList.toggle('active',active);
  if(active)a.setAttribute('aria-current','page');else a.removeAttribute('aria-current');
 });
 try{
  const overviewQuery=new URLSearchParams({days:$('#days').value==='custom'?'7':$('#days').value});
  if(params.has('since')){overviewQuery.set('since',params.get('since'));overviewQuery.set('until',params.get('until'));}
  const d=await api((['alarms','quality','cases','competitions','publications','tracks','players','races','studio','system','economy','live','product','analytics'].includes(section)?'studio/context?':'overview?')+overviewQuery);if(ticket!==generation)return;
  role=d.role;reporting=d;params=rangeParams(params);
  let html='';
  if(section==='alarms')html=await platformIncidents(id,params);
  else if(section==='quality')html=await platformQuality(params);
  else if(['tracks','players'].includes(section))html=await catalogueView(section,id,params);
  else if(section==='competitions'&&!id)html=await platformCompetitions(params);
  else if(['competitions','cases','publications'].includes(section)){html=await operationsView(section,id,params);if(section==='cases'&&id)html+=await platformCaseTriage(id);}
  else if(section==='product')html=await platformBehaviour(params);
  else if(section==='overview')html=await platformOverview(d,params);
  else if(section==='studio')html=params.get('tab')==='legacy'?await studioCoverage():await platformAdmin(params);
  else if(['players','tracks','races','audit','jobs','grants'].includes(section)){
   html=id?await inspect(section,id,params):intro(titles[section]||section,'Server records · search, filter and inspect stable identities')+await listing(section,params);
  }else if(section==='system'){
   html=intro('System & access','Operational visibility and accountable changes.','CONTROL')+tabs([['system','Health'],['system/jobs','Background jobs'],['system/audit','Audit history'],['system/access','Access']],path);
   if(id==='jobs')html=await platformJobs(params);else if(id==='audit')html+=await listing(id,params);
   else if(id==='access'){const q=new URLSearchParams(params);q.set('tab','access');html=await platformAdmin(q);}
   else html=platformOpsTabs('system',params)+monitorReliability(d,await api('competition-health'));
  }else if(section==='economy')html=await platformMoney(params);
  else if(section==='live'){const q=new URLSearchParams(params);q.set('tab','experiments');html=await platformAdmin(q);}
  else if(section==='analytics')html=intro('Race evidence','Inspect submitted results and their verification outcomes.','INVESTIGATE')+await listing('races',params);
  else html=intro('Page not found','Use the navigation to choose a workspace.');
  if(ticket!==generation)return;
  if(['tracks','publications','competitions'].includes(section))html=pTabs([['tracks','Track catalogue'],['publications','Publication requests'],['competitions','Competitions']],section,params)+html;if(['cases','players','races'].includes(section))html=pTabs([['cases','Support cases'],['players','Player directory'],['races','Race evidence']],section,params)+html;html='<div class="platform-actions"><button class="btn" id="platform-save">Save view</button>'+(section==='product'?'<button class="btn" id="platform-export">Export activity in scope</button>':'')+'</div>'+html;$('#main').innerHTML=html;
  if(lastRenderedRoute!==raw){window.scrollTo({top:0,behavior:'instant'});lastRenderedRoute=raw;}
  $('#role').textContent=role+' access';$('#environment').textContent=d.environment;
  $('#connection').textContent=location.host;$('#connection').title=location.origin;
  $('#freshness').textContent='Queried '+date(d.as_of);
  $('#date-range').textContent=new Date(d.since*1000).toISOString().slice(5,10)+' – '+new Date((d.until-1)*1000).toISOString().slice(5,10);
  if(new URLSearchParams(qs).has('since'))$('#days').value='custom';
  document.querySelectorAll('.console-nav').forEach(a=>{a.href=scopedHref(a.dataset.route,params);});
  wire(params);
 }catch(error){
  if(ticket!==generation||error.name==='AbortError')return;
  if(!key){login(error.message);return;}
  const denied=error.status===403;
  $('#main').innerHTML=intro(denied?'Access restricted':'Unable to load records',denied?'This credential does not permit the requested evidence.':'Previous values are not presented as current data.')+`<p class="console-error" role="alert">${esc(error.message)}</p><button id="retry" class="btn">Retry</button>`;
  $('#freshness').textContent='Query not completed';$('#retry').onclick=render;
 }finally{if(ticket===generation)$('#main').removeAttribute('aria-busy');}
}
function wire(params){const form=$('#filters');if(form)form.onsubmit=e=>{e.preventDefault();const p=new URLSearchParams(params);p.delete('offset');p.delete('cursor');for(const [name,value] of new FormData(form))value?p.set(name,value):p.delete(name);location.hash=location.hash.slice(1).split('?')[0]+'?'+p;};document.querySelectorAll('[data-offset]').forEach(b=>b.onclick=()=>{params.set('offset',b.dataset.offset);location.hash=location.hash.slice(1).split('?')[0]+'?'+params;});document.querySelectorAll('[data-page-cursor]').forEach(b=>b.onclick=()=>{params.delete('offset');params.set('cursor',b.dataset.pageCursor);location.hash=location.hash.slice(1).split('?')[0]+'?'+params;});if($('#command'))$('#command').onclick=()=>confirmCommand($('#command').dataset);wireCommerce(params);wireSupport();wireStudio();wireCatalogue();wireMonitor();wireInsights();wirePlatform(params);wireGameConfig(params);}
function dialogToken(){return {dialog:dialogGeneration,auth:authGeneration,page:generation};}
function dialogIsCurrent(token){return token.dialog===dialogGeneration&&token.auth===authGeneration&&token.page===generation&&$('#dialog').open;}
function modal(html){
 const dialog=$('#dialog');dialogGeneration++;
 if(!dialog.open)dialogOpener=document.activeElement;
 dialog.innerHTML=html;
 const title=dialog.querySelector('h2');if(title){title.id='dialog-title';dialog.setAttribute('aria-labelledby',title.id);}
 if(!dialog.open)dialog.showModal();
 dialog.querySelector('[data-close]')?.addEventListener('click',()=>dialog.close());
}
function confirmCommand(data){
 const player=data.kind==='players',current=data.value==='true',body={command_id:crypto.randomUUID(),entity_id:data.id,action:player?'player_restriction':'track_visibility',expected:current,value:!current,acknowledged:true};
 modal(`<h2>${player?'Account restriction':'Track visibility'} preview</h2><p>${player?'Restricting this account rejects player access and revokes existing sessions. Restoring it requires a fresh sign-in.':'Visibility applies to every version of this track. Published geometry, existing race evidence and publication state are retained.'}</p>${kv({entity_id:data.id,field:player?'disabled':'hidden',before:current,after:!current})}<form id="confirm"><label>Recorded reason<textarea id="reason" required minlength="8" maxlength="500"></textarea></label><label><input type="checkbox" required> I understand this change affects live backend records.</label><p id="command-error" class="console-error" hidden></p><div class="console-actions"><button type="button" class="btn" data-close>Cancel</button><button class="btn btn-primary" id="submit-command">Confirm change</button></div></form>`);
 const token=dialogToken();
 $('#confirm').onsubmit=async e=>{
  e.preventDefault();$('#submit-command').disabled=true;body.reason=$('#reason').value;
  try{await api('commands',body);if(!dialogIsCurrent(token))return;$('#dialog').close();render();}
  catch(error){if(!dialogIsCurrent(token))return;$('#command-error').hidden=false;$('#command-error').textContent=error.message;$('#submit-command').disabled=false;}
 };
}
function search(){
 if(!key)return;
 modal('<h2>Find a record</h2><form id="global-search"><label>Player, track, race, purchase or command identifier<input id="global-query" maxlength="100" required autofocus></label><button class="btn btn-primary">Search</button><button type="button" class="btn" data-close>Close</button></form><div id="search-results" role="status"></div>');
 const token=dialogToken();let searchGeneration=0;
 $('#global-search').onsubmit=async e=>{
  e.preventDefault();const current=++searchGeneration,q=$('#global-query').value;
  $('#search-results').textContent='Searching…';
  try{
   const results=await Promise.all(['players','tracks','races','audit','purchases'].map(async kind=>({kind,...await api((kind==='purchases'?'purchases':'entities/'+kind)+'?limit=8&q='+encodeURIComponent(q))})));
   if(!dialogIsCurrent(token)||current!==searchGeneration)return;
   $('#search-results').innerHTML=results.map(d=>d.items.map(r=>`<a class="console-search-result" href="${d.kind==='purchases'?'#players/'+encodeURIComponent(r.player_id)+'?kind=purchase&all=1&q='+encodeURIComponent(r.id):scopedHref(d.kind+'/'+encodeURIComponent(r.id))}">${esc(r.display_name||r.name||r.id)} <small>· ${d.kind}</small></a>`).join('')).join('')||'<p class="console-empty">No matching records.</p>';
   $('#search-results').querySelectorAll('a').forEach(a=>a.onclick=()=>$('#dialog').close());
  }catch(error){if(!dialogIsCurrent(token)||current!==searchGeneration)return;$('#search-results').textContent=error.message;}
 };
}
function clearAccess(){
 authGeneration++;key='';role='';reporting=null;readController?.abort();
 supportCurrent=null;supportBack.clear();studioCurrent=null;
 $('#role').textContent='Authentication required';$('#environment').textContent='Disconnected';
 $('#connection').textContent='Same-origin backend';$('#freshness').textContent='';
 $('#date-range').textContent='Dates';if($('#dialog').open)$('#dialog').close();
 dialogGeneration++;$('#dialog').replaceChildren();dialogOpener=null;
}
function setNavigation(open){$('#sidebar').classList.toggle('open',open);$('#menu').setAttribute('aria-expanded',String(open));}
$('#nav').innerHTML=sections.map(([id,name,icon,group])=>`${group?`<p class="nav-group">${group}</p>`:''}<a class="console-nav" data-route="${id}" href="#${id}"><span aria-hidden="true">${icon}</span>${esc(name)}</a>`).join('');
$('#dialog').addEventListener('close',()=>{dialogGeneration++;if(dialogOpener?.isConnected)dialogOpener.focus();dialogOpener=null;});
$('.studio-skip').onclick=event=>{event.preventDefault();$('#main').focus();};
$('#close-nav').onclick=()=>setNavigation(false);
$('#menu').onclick=()=>setNavigation(!$('#sidebar').classList.contains('open'));
$('#refresh').onclick=render;
$('#days').onchange=()=>{
 if($('#days').value==='custom'){reportingDates();return;}
 const [path,qs]=location.hash.slice(1).split('?'),params=new URLSearchParams(qs);
 for(const name of ['since','until','cursor','offset','all'])params.delete(name);
 const next='#'+(path||'overview')+(params.size?'?'+params:'');if(location.hash===next)render();else location.hash=next;
};
$('#date-range').onclick=reportingDates;
$('#logout').onclick=()=>{clearAccess();setNavigation(false);login();};
$('#search').onclick=search;
window.addEventListener('hashchange',()=>{setNavigation(false);render();});
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&$('#sidebar').classList.contains('open')&&!$('#dialog').open){e.preventDefault();setNavigation(false);$('#menu').focus();return;}if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='k'){e.preventDefault();search();}});
render();
