'use strict';
// Workspaces share explicit date/population context and retain stable evidence links.
const pNumber=v=>v==null?'Unavailable':Number(v).toLocaleString('en-GB');
const pPercent=(n,d)=>n==null||!d?'Unavailable':(100*n/d).toFixed(1)+'%';
function pLink(target,label,params){return `<a class="btn" href="${scopedHref(target,params)}">${esc(label)}</a>`;}
function pTabs(items,selected,params){return `<nav class="platform-tabs" aria-label="Workspace views">${items.map(([target,label])=>{const [path,qs]=target.split('?'),q=new URLSearchParams(qs);for(const key of ['build_id','baseline','platform','mode','population'])if(params?.has(key)&&!q.has(key))q.set(key,params.get(key));return `<a ${target===selected?'aria-current="page"':''} href="${scopedHref(path+(q.size?'?'+q:''),params)}">${esc(label)}</a>`;}).join('')}</nav>`;}
function pTable(headers,rows,empty='No observations in this scope.'){
 return `<div class="console-table platform-table"><table><thead><tr>${headers.map(v=>`<th scope="col">${esc(v)}</th>`).join('')}</tr></thead><tbody>${rows.map(row=>`<tr>${row.map(v=>`<td>${v}</td>`).join('')}</tr>`).join('')}</tbody></table>${rows.length?'':`<p class="console-empty">${esc(empty)}</p>`}</div>`;
}
function pStat(label,value,note,target){return `<${target?'a':'section'} ${target?`href="${scopedHref(target)}"`:''} class="platform-stat"><span>${esc(label)}</span><strong>${esc(value)}</strong><small>${esc(note)}</small></${target?'a':'section'}>`;}
function pNotice(title,body,kind=''){return `<aside class="platform-notice ${kind}" role="status"><b>${esc(title)}</b><p>${esc(body)}</p></aside>`;}
function pScope(d){return `<p class="platform-scope">${esc(date(d.since))} to ${esc(date(d.until))} · end excluded · UTC calendar days · ${esc(d.filters?.population||'all')} players</p>`;}
function pOptions(values,selected,empty){const list=[...new Set(values.filter(Boolean))].sort();return `<option value="">${esc(empty)}</option>${selected&&!list.includes(selected)?`<option selected value="${esc(selected)}">${esc(selected)} · no matching observations</option>`:''}${list.map(v=>`<option value="${esc(v)}" ${v===selected?'selected':''}>${esc(v)}</option>`).join('')}`;}
function pFilters(d,params,quality=false){
 const options=d.options||[],select=(name,label,values,empty)=>`<label>${esc(label)}<select name="${name}">${pOptions(values,params.get(name),empty)}</select></label>`;
 return `<form id="filters" class="platform-filters">`+
 select('build_id','Build',quality?d.builds:options.map(v=>v.build_id),'All builds')+
 (quality?select('baseline','Baseline',d.builds,'Choose baseline'):'')+
 select('platform','Platform',quality?['android','ios','windows','linux','macos']:options.map(v=>v.platform),'All platforms')+
 (quality?select('device_model','Device',options.map(v=>v.device_model),'All devices')+
 select('os_version','OS version',options.map(v=>v.os_version),'All OS versions')+
 select('track_version_id','Track version',options.map(v=>v.track_version_id),'All track versions')+
 select('render_context_key','Render context',options.map(v=>v.render_context_key),'All render contexts'):
 select('mode','Mode',options.map(v=>v.mode),'All modes')+
 `<label>Population<select name="population"><option value="all">All players</option>${d.business_cohorts_enabled?`<option value="real" ${params.get('population')==='real'?'selected':''}>Real players</option><option value="artificial" ${params.get('population')==='artificial'?'selected':''}>Artificial drivers</option>`:''}</select></label>`)+
 `<button class="btn btn-primary">Apply scope</button></form>`;
}
function pScopeNote(params,quality=false){
 const unsupported=(quality?['mode','population']:['baseline','device_model','os_version','track_version_id','render_context_key']).filter(k=>params.get(k)&&params.get(k)!=='all');
 return unsupported.length?pNotice('Scope carried for your investigation',`This report does not apply ${unsupported.map(k=>k.replaceAll('_',' ')).join(', ')}. These selections remain in the link for returning to the other workspace. ${quality?'Quality package totals include all reporting players.':'Only the filters shown for this report affect its totals.'}`):'';
}
function pReportFreshness(c,asOf){
 const stamp=c.processed_through,latest=c.latest_client_at??c.latest_package_at;
 const old=latest&&asOf-latest>900,disabled=c.collection_enabled===false,pending=c.pending_events;
 const title=disabled?'Collection is disabled':!stamp?'Projection watermark unavailable':pending>0?'Observations are waiting for projection':old?'Source observations are older than 15 minutes':'Source freshness';
 const message=`Processed through ${date(stamp)}. Latest observation ${date(latest)}. ${pending==null?'Pending count unavailable.':pNumber(pending)+' observations pending.'} `+
 (old?'Old evidence can reflect quiet traffic or delayed collection; this does not establish a failed collector. ':'')+
 `Queried ${date(asOf)}. Current UTC days and partly covered days are incomplete.`;
 return `<div data-report-watermark="${esc(stamp||'')}">${pNotice(title,message,disabled||old||pending>0||!stamp?'warning':'')}</div>`;
}
function pExportAction(section,params){
 const view=section==='product'?(['retention','journey','engagement'].includes(params.get('tab'))?params.get('tab'):'activity'):
 section==='quality'&&(!params.get('tab')||params.get('tab')==='compare')?'releases':null;
 return view?`<button class="btn" id="platform-export" data-view="${view}">Export ${view==='releases'?'release comparison':view==='journey'?'first-race journey':view} CSV</button><span id="platform-export-status" role="status"></span>`:'';
}
function pExportNote(){return '<p class="platform-method">CSV downloads run a new query of the selected report and filters. Each row includes the query time, source watermark, effective dates and scope so it can be reconciled with this view.</p>';}


function pQuery(params,allowed){const q=new URLSearchParams();for(const name of ['since','until',...allowed])if(params.has(name))q.set(name,params.get(name));return q;}

async function platformOverview(d,params){
 const reads=await Promise.allSettled([api('incidents?limit=6'),api('metrics')]);
 const incidents=reads[0].status==='fulfilled'?reads[0].value:null,metrics=reads[1].status==='fulfilled'?reads[1].value:null;
 const coverage=metrics?.coverage||{},actionable=incidents?(incidents.counts.open||0)+(incidents.counts.acknowledged||0):null;
 const failure=(label)=>pNotice(label+' is unavailable','Other successful sources remain visible. Refresh to retry this source.','warning');
 const pulse='races?state=verified&time_field=finished_at&since='+d.pulse_since+'&until='+(d.pulse_until+1);
 return intro('Know what needs attention.','Start with player impact, then follow the evidence into a focused workspace.','GAME OPERATIONS')+
 `<div class="platform-stats">${pStat('Active incidents',pNumber(actionable),'Open and acknowledged occurrences','alarms')}${pStat('Verification jobs',pNumber(d.pending),'Current shared verification queue','system/jobs')}${pStat('Verified results',pNumber(d.states.verified||0),'Last five minutes - verification terminal time',pulse)}${pStat('Reporting data age',coverage.latest_client_at?Math.max(0,Math.floor((Date.now()/1000-coverage.latest_client_at)/60))+' min':'Unavailable','Latest received client observation','product')}</div>`+
 (incidents?card('React and recover',incidents.items.length?incidents.items.map(r=>`<article class="platform-incident"><span class="platform-tag ${esc(r.severity)}">${esc(r.state)}</span><h3>${esc(r.title)}</h3><p>${esc(r.evidence.evidence)}</p>${pLink('alarms/'+r.id,'Investigate',params)}</article>`).join(''):'<p>No retained actionable incidents. Check source coverage before inferring a healthy service.</p>'):failure('Incident evidence'))+
 `<div class="platform-grid">${card('Understand player behaviour','<p>Follow activity, exact-day returns and the first-race journey. Read population and follow-up coverage before interpreting changes.</p>'+pLink('product','Explore behaviour',params))}${card('Protect game quality','<p>Compare a release with a baseline, find affected devices and follow a track into its diagnostic evidence.</p>'+pLink('quality','Compare releases',params))}${card('Optimise monetisation','<p>Review provider earnings, purchase delivery and Coin sources and sinks as separate measures.</p>'+pLink('economy','Review monetisation',params))}${metrics?card('Can these numbers be trusted?',`<dl class="platform-definitions"><dt>Client observations</dt><dd>${esc(date(coverage.latest_client_at))}</dd><dt>Reporting watermark</dt><dd>${esc(date(coverage.processed_through))}</dd><dt>Monetary revenue import</dt><dd>${esc(date(coverage.latest_finance_import))}</dd><dt>Guests / crash stacks / Play Vitals</dt><dd>Unavailable</dd></dl>`+pLink('studio','Inspect definitions & coverage',params)):failure('Metric coverage')}</div>`;
}

async function platformBehaviour(params){
 const tab=['retention','journey','engagement'].includes(params.get('tab'))?params.get('tab'):'activity';
 const head=intro('Player behaviour','Find where players return, struggle or leave, with the observation limits visible.','UNDERSTAND')+
 pTabs([['product','Activity'],['product?tab=retention','Retention'],['product?tab=journey','First-race journey'],['product?tab=engagement','Engagement']],tab==='activity'?'product':'product?tab='+tab,params);
 const d=await api('analysis/behaviour?'+pQuery(params,['build_id','platform','mode','population'])+'&view='+tab),c=d.counters;
 const coverage=d.coverage;
 let body='';
 if(tab==='engagement'){
  const e=d.engagement;
  body=`<div class="platform-stats">${pStat('Observed sessions',pNumber(e.sessions),'Sessions first observed in the window')}${pStat('Sessions reporting duration',pNumber(e.sessions_with_duration),'At least one foreground interval')}${pStat('Reported foreground time',(e.foreground_ms/3600000).toFixed(1)+' h','Across sessions first observed in scope')}${pStat('Mean observed duration',e.sessions_with_duration?(e.foreground_ms/e.sessions_with_duration/60000).toFixed(1)+' min':'Unavailable','Among sessions reporting duration')}</div>`+pNotice('Interpret session duration with coverage','A last interval can be missing after a crash or exit. Concurrent devices and missing reports affect totals. Mode filtering does not apply to sessions; build/platform use the first observation in a session.');
 }else if(tab==='retention'){
  body=card('Do players return?',`<p>Exact-day return to any build. Cohorts use their first observed build and platform. Mode filters activity only. A mature result can restate during the next seven days.</p>`+pTable(['First observed UTC day','Cohort','D1','D7','D30'],d.retention.map(r=>[esc(r.day),pNumber(r.players),...[1,7,30].map(n=>r['d'+n].mature?`${pPercent(r['d'+n].returned,r['d'+n].eligible)} <small>${pNumber(r['d'+n].returned)} / ${pNumber(r['d'+n].eligible)} · ${r['d'+n].finalised?'finalised':'provisional'}</small>`:'<span class="platform-muted">Follow-up pending</span>')])));
 }else if(tab==='journey'){
  const f=d.first_race,max=f.eligible||1;
  body=card('Where does the first race journey break?',`<p>${pNumber(f.eligible)} eligible first-observed players · 24 hours plus 10 minutes follow-up. ${f.truncated_profiles?pNumber(f.truncated_profiles)+' truncated profiles prevent a complete funnel.':''}</p><ol class="platform-journey">${f.steps.map((s,i)=>`<li><span>${i+1}. ${esc(s.name.replaceAll('_',' '))}</span><strong>${pNumber(s.players)}</strong><div class="platform-track"><span style="width:${Math.min(100,100*(s.players||0)/max)}%"></span></div></li>`).join('')}</ol><p>Client finish and authoritative acceptance are distinct steps. Investigate telemetry coverage before treating an observed drop as player abandonment.</p>`);
 }else{
  body=`<div class="platform-stats">${pStat('Observed active players',coverage.available?pNumber(d.active_players):'Unavailable','Distinct signed-in players in scope')}${pStat('Race starts',coverage.available?pNumber(c.race_started):'Unavailable','Client observations')}${pStat('Accepted results',coverage.available?pNumber(c.race_accepted):'Unavailable','Authoritative server facts')}${pStat('Foreground time',coverage.available?(c.foreground_ms/3600000).toFixed(1)+' h':'Unavailable','Reported intervals; missing intervals excluded')}</div>`+
  card('Activity by day',pTable(['UTC day','Active players','Starts','Observed finishes','Accepted results','Coverage'],d.daily.map(r=>[esc(new Date(r.day*86400000).toISOString().slice(0,10)),pNumber(r.players),pNumber(r.starts),pNumber(r.finishes),pNumber(r.accepted),esc(r.coverage_state==='partial'?'In progress':r.coverage_state==='unobserved'?'Not observed':'Observed')])))+
  card('Next questions',`<div class="console-actions">${pLink('product?tab=retention','Are players returning?',params)}${pLink('product?tab=journey','Where do first races stop?',params)}${pLink('quality','Does release quality explain a drop?',params)}</div>`);
 }
 return head+pFilters(d,params)+pScope(d)+pScopeNote(params)+pReportFreshness(coverage,d.as_of)+(coverage.collection_enabled===false?pNotice('Collection is disabled','Retained observations remain available. They do not establish current player activity.','warning'):'')+(coverage.available?'':pNotice('Client coverage is unavailable','No client observations have reached this analytical projection. Server activity alone does not establish complete behaviour coverage.','warning'))+body+
 `${pExportNote()}<details class="platform-method"><summary>Definition, freshness and limits</summary><p>Analysis began ${esc(date(coverage.started_at))}; processed through ${esc(date(coverage.processed_through))}. ${pNumber(coverage.pending_events)} observations pending.</p><p>${esc(coverage.definition)}</p><p>${esc(coverage.foreground)}</p><p>Guests are unavailable. These totals include artificial drivers unless an explicitly enabled population filter is selected. Existing historical totals remain available separately.</p>${d.options_truncated?'<p>Build selector is limited to 200 combinations; metrics use the full selected scope.</p>':''}</details>`;
}

async function platformQuality(params){
 if(params.get('tab')&&params.get('tab')!=='compare')return pTabs([['quality','Release comparison'],['quality?tab=diagnostics','Track & device diagnostics']],'quality?tab=diagnostics',params)+pScopeNote(params,true)+await monitorQualityView(params);
 const fields=['build_id','baseline','platform','device_model','os_version','track_version_id','render_context_key'];
 const d=await api('analysis/releases?'+pQuery(params,fields));
 const rate=(n,total)=>n==null||!total?'Unavailable':pPercent(n,total)+` <small>${pNumber(n)} / ${pNumber(total)}</small>`;
 const delta=value=>value==null?'Unavailable':(value>0?'+':'')+(value*100).toFixed(2)+' pp';
 const one=(r,label)=>r?card(label,`<h3>${esc(r.build_id)}</h3>`+
 (!r.attempts?pNotice('No package coverage','No packages match this build and scope. Zero affected users is not inferred.','warning'):
 !r.sample_sufficient?pNotice('Small exploratory sample',`Below ${d.sample_policy.minimum_packages} packages or ${d.sample_policy.minimum_frames} frames. This is not a release decision.`,'warning'):'')+
 `<dl class="platform-definitions"><dt>Observed completion</dt><dd>${rate(r.finished,r.attempts)}</dd><dt>Frames over 34 ms</dt><dd>${rate(r.slow_frames,r.frames)}</dd><dt>Reporting players</dt><dd>${pNumber(r.reporting_players)}</dd><dt>Players reporting slow frames</dt><dd>${pNumber(r.affected_players)}</dd><dt>Last selected package</dt><dd>${esc(date(r.latest_package_at))}</dd></dl>`+
 (r.player_coverage!=='available'?'<p>Player coverage is unavailable for this scope. Package and frame counters have their own denominator.</p>':'')+
 pLink('quality?tab=frames&'+pQuery(new URLSearchParams({...Object.fromEntries(params),build_id:r.build_id}),fields),'Inspect these frame samples',params)):
 card(label,'<p>Choose a build to inspect its reporting population.</p>');
 const diagnostic=(r,build,tab)=>{const q=new URLSearchParams(params);q.set('tab',tab);q.set('build_id',build);for(const k of ['platform','device_model','os_version','render_context_key'])r[k]?q.set(k,r[k]):q.delete(k);return pLink('quality?'+q,(tab==='frames'?'Frame times':'Track heatmap'),params);};
 const source={...d.source,latest_package_at:d.candidate?.latest_package_at??d.baseline?.latest_package_at};
 return intro('Game quality','Compare the same build, device, OS and track scope, then follow the evidence.','PROTECT')+
 pTabs([['quality','Release comparison'],['quality?tab=diagnostics','Track & device diagnostics'],['studio?tab=releases','Release registry']],'quality',params)+
 pFilters(d,params,true)+pScope(d)+pScopeNote(params,true)+pReportFreshness(source,d.as_of)+
 `<div class="platform-grid">${one(d.candidate,'Candidate')}${one(d.baseline,'Baseline')}</div>`+
 (d.comparison?pNotice('Descriptive differences',`Completion ${delta(d.comparison.completion_change)}; frames over 34 ms ${delta(d.comparison.slow_frame_change)}. ${d.comparison.sample_sufficient?'':'Samples are small. '}Unselected player, device, render setup and track mix can differ. No rollout verdict or causal claim is made.`,d.comparison.completion_change<0||d.comparison.slow_frame_change>0?'warning':''):'')+
 card('Candidate devices to investigate',pTable(['Device / platform','OS / render context','Packages','Candidate slow frames','Baseline slow frames','Difference','Investigate'],d.segments.map(r=>[
 `${esc(r.device_model)}<small>${esc(r.platform)}</small>`,`${esc(r.os_version)}<small>${esc(r.render_context_key||'Unknown context')}</small>`,pNumber(r.attempts),rate(r.slow_frames,r.frames),rate(r.baseline_slow_frames,r.baseline_frames),esc(delta(r.slow_change))+(r.sample_sufficient?'':'<small>Small / missing comparison sample</small>'),diagnostic(r,d.filters.build_id,'frames')+' '+diagnostic(r,d.filters.build_id,'heatmap')]))+
 `<p>${d.segments_truncated?'Showing 20 device segments with the highest observed slow-frame shares. ':''}${esc(d.coverage)}</p>`)+
 pExportNote()+`<p class="platform-method">Exploratory sample policy: ${d.sample_policy.minimum_packages} packages and ${d.sample_policy.minimum_frames} frames per build. These are visibility warnings, not validated launch thresholds.</p>`;
}

function platformOpsTabs(current,params){return pTabs([['alarms','Incidents'],['alarms?tab=checks','Current checks'],['alarms?tab=history','Monitor history'],['alarms?tab=notifications','Notifications'],['system/jobs','Worker queues'],['system','Service health'],['analytics','Result submissions']],current,params);}

async function platformIncidents(id,params){
 if(params.get('tab')==='notifications'){
  const d=await api('notifications?state='+encodeURIComponent(params.get('state')||'dead'));
  return intro('Notification delivery','Inspect exhausted retries and record the next action.','OPERATE')+platformOpsTabs('alarms?tab=notifications',params)+
  `<form id="filters" class="platform-filters"><label>State<select name="state">${['dead','pending','delivered','dismissed'].map(s=>`<option ${params.get('state')===s?'selected':''}>${s}</option>`).join('')}</select></label><button class="btn">Apply</button></form>`+
  card('Delivery events',pTable(['Created','State','Attempts','Last result','Incident','Action'],d.items.map(r=>[esc(date(r.created_at)),esc(r.state),pNumber(r.attempts),esc(r.last_error||'Unavailable'),pLink('alarms/'+r.incident_id,'Inspect incident',params),role==='owner'&&r.state==='dead'?`<button class="btn" data-notification="retry" data-id="${r.id}" data-attempts="${r.attempts}">Retry delivery</button><button class="btn" data-notification="dismiss" data-id="${r.id}" data-attempts="${r.attempts}">Dismiss</button>`:'No action required'])))+`<p>${esc(d.scope)} ${d.truncated?'Latest 50 events only.':''}</p>`;
 }
 if(params.get('tab')==='history'){
  const d=await api('monitor/history');return intro('Monitor history','Follow observed recovery and verify collection continuity.','OPERATE')+platformOpsTabs('alarms?tab=history',params)+
  card('Recent observations',pTable(['Observed','Source','Signals','Server request coverage'],d.items.map(r=>[esc(date(r.observed_at)),esc(r.source),r.signals.map(s=>`<span class="platform-tag ${s.active?esc(s.severity):''}">${esc(s.key)}: ${s.active==null?'Unknown':s.active?'Firing':'Clear'}</span>`).join(' '),r.http?`${r.http.complete?'Complete export declared':'Incomplete export'}<small>${r.http.windows.map(w=>w.requests+' requests / '+w.seconds+'s').join(' · ')}</small>`:'Readiness / worker metadata'])))+`<p>${esc(d.scope)} ${d.truncated?'Latest 200 observations only.':''} Retention: ${d.retention_days} days.</p>`;
 }
 if(params.get('tab')==='checks'||(id&&!/^[a-f0-9-]{36}$/.test(id)))return platformOpsTabs('alarms?tab=checks',params)+await insightAlarms(id,params);
 if(id){
  const d=await api('incidents/'+encodeURIComponent(id)),r=d.item;
  return intro(r.title,'Occurrence '+r.occurrence+' · '+r.source+' · '+r.signal,'REACT')+platformOpsTabs('alarms',params)+
  pNotice(r.state.toUpperCase()+' · '+r.severity,r.evidence.evidence,r.state==='open'?'warning':'')+(d.signal.known===false?pNotice('Current evidence is unknown','The last firing condition remains visible. A missing or incomplete observation does not establish recovery.','warning'):'')+
  card('What to do next',`<p>${esc(r.evidence.next_step)}</p><div class="console-actions">${pLink(r.evidence.target,'Open evidence',params)}${pLink('cases','Support investigations',params)}${pLink('alarms','All incidents',params)}</div>`)+
  card('Own the response',`<dl class="platform-definitions"><dt>Opened</dt><dd>${esc(date(r.opened_at))}</dd><dt>Last observation</dt><dd>${esc(date(d.signal.observed_at))}</dd><dt>Recovery</dt><dd>${esc(date(r.recovered_at))}</dd><dt>Assigned to</dt><dd>${esc(r.assignee||'Unassigned')}</dd><dt>Notifications suppressed until</dt><dd>${esc(date(d.signal.suppressed_until))}</dd></dl>${role==='owner'?`<div class="console-actions">${r.state==='open'?`<button class="btn btn-primary" data-incident="acknowledge" data-id="${esc(r.id)}" data-revision="${r.revision}">Acknowledge</button>`:''}${r.state==='recovered'?`<button class="btn btn-primary" data-incident="clear" data-id="${esc(r.id)}" data-revision="${r.revision}">Clear recovered issue</button>`:''}<button class="btn" data-incident="assign" data-id="${esc(r.id)}" data-revision="${r.revision}">Assign owner</button><button class="btn" data-incident="suppress" data-id="${esc(r.id)}" data-revision="${r.revision}">Suppress notifications</button></div>`:'<p>Owner access is required to change an incident.</p>'}<p>Acknowledgement records ownership. Clearing is available after observed recovery. A recurrence opens a new occurrence.</p>`)+
  card('Response history',pTable(['When','Action','Actor','Reason'],d.history.map(e=>[esc(date(e.created_at)),esc(e.kind),esc(e.actor),esc(e.detail.reason||e.detail.evidence||'')])));
 }
 const d=await api('incidents?state='+encodeURIComponent(params.get('state')||'actionable')+(params.has('cursor')?'&cursor='+encodeURIComponent(params.get('cursor')):''));
 return intro('Operations & alarms','A durable response desk: open, acknowledge, recover, clear.','REACT')+platformOpsTabs('alarms',params)+
 `<div class="platform-stats">${pStat('Needs acknowledgement',pNumber(d.counts.open||0),'Open occurrences')}${pStat('Under investigation',pNumber(d.counts.acknowledged||0),'Acknowledged occurrences')}${pStat('Ready to clear',pNumber(d.counts.recovered||0),'Observed recovery')}${pStat('Notification retries',pNumber(d.delivery.pending||0),(d.delivery.dead||0)+' exhausted deliveries')}</div>`+
 (!d.sources.length?pNotice('Continuous monitoring has no observations','Start the independent watchdog and configure its dedicated source token. Current checks remain available as an on-demand snapshot.','warning'):d.sources.some(s=>s.stale||s.unknown_signals)?pNotice('Monitoring evidence is incomplete','One or more checks are unknown or missed expected collection intervals. Last known incident states remain visible; recovery is not inferred.','warning'):'')+
 `<form id="filters" class="platform-filters"><label>Incident state<select name="state">${['actionable','all','open','acknowledged','recovered','closed'].map(s=>`<option ${params.get('state')===s?'selected':''}>${s}</option>`).join('')}</select></label><button class="btn">Apply</button></form>`+
 card('Incident desk',pTable(['Severity / state','Issue','Last seen','Owner','Action'],d.items.map(r=>[`<span class="platform-tag ${esc(r.severity)}">${esc(r.severity)}</span><small>${esc(r.state)}</small>`,`<b>${esc(r.title)}</b><small>${esc(r.source)} · occurrence ${r.occurrence}</small>`,esc(date(r.last_seen_at)),esc(r.assignee||'Unassigned'),pLink('alarms/'+r.id,'Investigate',params)]))+`<p>Current incident states across retained history; the reporting window does not filter this desk.</p><div class="console-actions">${params.has('cursor')?pLink('alarms?state='+encodeURIComponent(params.get('state')||'actionable'),'First page',params):''}${d.next_cursor?pLink('alarms?state='+encodeURIComponent(params.get('state')||'actionable')+'&cursor='+encodeURIComponent(d.next_cursor),'Older occurrences',params):''}</div>`)+
 card('Monitor coverage',pTable(['Source','Last receipt','Freshness'],d.sources.map(s=>[esc(s.source),esc(date(s.last_receipt_at)),s.stale?'Stale':'Current']))+`<p>${d.notifications_configured?'Signed notification delivery is configured.':'Notification destination is not configured.'} ${d.truncated?'The desk shows its latest 50 matching occurrences.':''}</p>`);
}

async function platformJobs(params){
 const d=await api('jobs?'+pQuery(params,['state','kind','cursor']));
 return intro('Worker queues','See which work is waiting and where players may be affected.','OPERATE')+platformOpsTabs('system/jobs',params)+
 `<form id="filters" class="platform-filters"><label>State<select name="state">${['pending','failed','all'].map(s=>`<option ${params.get('state')===s?'selected':''}>${s}</option>`).join('')}</select></label><label>Worker kind<select name="kind">${pOptions(d.summary.map(s=>s.kind),params.get('kind'),'All worker kinds')}</select></label><button class="btn">Apply</button></form>`+
 card('All work, one view',pTable(['Worker kind','Pending','Oldest','Failed / exhausted'],d.summary.map(s=>[esc(s.kind),(s.pending_capped?'At least ':'')+pNumber(s.pending),esc(date(s.oldest_at)),(s.failed_capped?'At least ':'')+pNumber(s.failed)])))+
 card('Activity projection',`<p>${pNumber(d.projection?.pending)} pending ${d.projection?.capped?'(count capped)':''} · processed through ${esc(date(d.projection?.processed_through))}</p>`)+
 card('Oldest matching work',pTable(['Kind','State','Record','Time'],d.items.map(r=>[esc(r.kind),esc(r.status),['race','publication'].includes(r.kind)?link(r.kind==='race'?'races':'publications',r.id):esc(r.id),esc(date(r.created_at))]))+`<p>${esc(d.scope)}</p><div class="console-actions">${params.has('cursor')?pLink('system/jobs?'+pQuery(params,['state','kind']),'First page',params):''}${d.next_cursor?pLink('system/jobs?'+pQuery(params,['state','kind'])+'&cursor='+encodeURIComponent(d.next_cursor),'Next oldest work',params):''}</div>`);
}

async function platformCompetitions(params){
 if(params.get('kind')==='ranking')return rankingWorkspace(params);
 const kind=params.get('kind')==='challenge'?'challenge':'rivalry',q=new URLSearchParams({kind,offset:params.get('offset')||'0',state:params.get('state')||'all',q:params.get('q')||''});
 const d=await api('competitions?'+q),page=offset=>{const next=new URLSearchParams(q);next.set('offset',offset);return 'competitions?'+next;};
 return intro('Competitions','Find the event, then inspect its pinned rules and accepted-result evidence.','INVESTIGATE')+
 pTabs([['competitions?kind=rivalry','Weekly Rivalry'],['competitions?kind=challenge','Challenges'],['competitions?kind=ranking','World Ranking']],'competitions?kind='+kind,params)+
 (kind==='rivalry'?await rivalryCalendar(params):'')+
 `<form id="filters" class="platform-filters"><label>State<select name="state">${['all','active','ended'].map(s=>`<option ${q.get('state')===s?'selected':''}>${s}</option>`).join('')}</select></label><label>Stable identifier<input name="q" value="${esc(q.get('q'))}" maxlength="100"></label><button class="btn">Find competition</button></form>`+
 card(kind==='rivalry'?'Weekly groups':'Player challenges',pTable(['Competition','Context','Ends','Entrants','Action'],d.items.map(r=>[`<b>${kind==='rivalry'?'Week of '+new Date(r.week_start*1000).toISOString().slice(0,10):esc(r.name)}</b><small>${esc(r.id)}</small>`,kind==='rivalry'?esc(r.vehicle_id)+(r.archived?' · Archived':''):`${esc(r.mode)}<small>Created by ${esc(r.creator_name)}</small>`,esc(date(r.ends_at)),pNumber(r.member_count),pLink('competitions/'+r.id+'?kind='+kind,'Inspect event',params)])))+
 `<div class="console-pager"><span>Page ${1+Math.floor(d.offset/d.limit)}</span>${d.offset?pLink(page(Math.max(0,d.offset-d.limit)),'Previous',params):''}${d.next_offset!=null?pLink(page(d.next_offset),'Next',params):''}</div>`;
}

async function platformCaseTriage(id){
 const d=await api('cases/'+id+'/triage');
 return card('Response owner & priority',`<dl class="platform-definitions"><dt>Owner</dt><dd>${esc(d.assignee||'Unassigned')}</dd><dt>Priority</dt><dd>${esc(d.priority)}</dd><dt>Due</dt><dd>${esc(date(d.due_at))}${d.due_at&&d.due_at<Date.now()/1000?' · Overdue':''}</dd><dt>Related incident</dt><dd>${d.incident_id?pLink('alarms/'+d.incident_id,'Inspect incident'): 'None linked'}</dd></dl>${role==='owner'?`<button class="btn" data-case-triage="${id}" data-triage="${esc(JSON.stringify(d))}">Assign & prioritise</button>`:''}`);
}

async function platformMoney(params){
 if(params.get('tab')==='delivery')return pTabs([['economy','Value & revenue'],['economy?tab=delivery','Purchase delivery']], 'economy?tab=delivery',params)+await commercePage(params);
 const d=await api('finance?'+pQuery(params,[]));
 return intro('Monetisation','Connect verified value, purchase delivery and a balanced noncash economy.','OPTIMISE')+
 pTabs([['economy','Value & revenue'],['economy?tab=delivery','Purchase delivery']], 'economy',params)+pScope(d)+
 (!d.money.length?pNotice('Monetary revenue is unavailable','No provider revenue entries exist in this scope. Product prices, purchase requests and Coins are not revenue.','warning'):'')+
 card('Provider earnings',pTable(['Provider','Type','Currency','Accounting basis','Amount','Last import'],d.money.map(r=>[esc(r.provider),esc(r.kind.replaceAll('_',' ')),esc(r.currency),esc(r.basis),(r.amount_micros/1000000).toFixed(2),esc(date(r.last_import_at))])))+
 `<div class="platform-grid">${card('Coin sources and sinks',pTable(['Movement','Coins','Entries'],d.coins.map(r=>[esc(r.kind),pNumber(r.amount),pNumber(r.entries)]))+`<p>Opening balances are excluded from earnings. Open a player to inspect their current wallet and access.</p>`)}${card('Source connections',`<dl class="platform-definitions"><dt>Google Play verification</dt><dd>${d.sources.play_configured?'Configured':'Not configured'}</dd><dt>AdMob network reports</dt><dd>${d.sources.admob_configured?'Configured':'Not configured'}</dd><dt>Latest money import</dt><dd>${esc(date(d.sources.latest_import_at))}</dd><dt>Player LTV / ARPDAU</dt><dd>Unavailable until attributable value and population coverage exist</dd></dl>`+pLink('economy?tab=delivery','Inspect purchase delivery',params))}</div><p class="platform-method">${esc(d.coverage)}</p>`;
}

async function platformAdmin(params){
 const tab=params.get('tab')||'definitions';
 const head=intro('Administration','Definitions, access and controlled changes that make decisions accountable.','MANAGE')+
 pTabs([['studio','Metrics & coverage'],['studio?tab=saved','Saved views'],['studio?tab=releases','Releases'],['studio?tab=config','Game Configuration'],['studio?tab=experiments','A/B testing'],['studio?tab=access','Staff & access'],['system/audit','Audit history']],tab==='definitions'?'studio':'studio?tab='+tab,params);
 if(tab==='config')return head+await gameConfigView(params);
 if(tab==='experiments')return head+await gameConfigExperiments(params);
 if(tab==='saved'){
  const d=await api('saved-views');return head+card('Saved reporting views',pTable(['Name','Location','Updated','Actions'],d.items.map(r=>[esc(r.name),esc(r.route),esc(date(r.updated_at)),pLink(r.route+'?'+new URLSearchParams(r.filters),'Open view',null)+` <button class="btn" data-saved-rename="${esc(JSON.stringify(r))}">Rename</button> <button class="btn" data-saved-delete="${esc(JSON.stringify(r))}">Delete</button>`])))+'<p>Saved locations retain supported record IDs, queue destinations, dates and filters. Shared legacy keys share a view owner.</p>';
 }
 if(tab==='access'){
  const d=await api('staff');return head+card('Your access',`<dl class="platform-definitions"><dt>Signed in as</dt><dd>${esc(d.display_name)}</dd><dt>Actor</dt><dd>${esc(d.actor)}</dd><dt>Role</dt><dd>${esc(d.role)}</dd><dt>Named sign-in</dt><dd>${d.named_signin_configured?'Configured':'Not configured'}</dd><dt>Legacy keys</dt><dd>${d.legacy_keys_enabled?'Enabled':'Disabled'}</dd><dt>MFA claim policy</dt><dd>${d.mfa_required?'Required for named sign-in':'Not required'}</dd></dl><p>Named sign-in accepts only separately configured staff audiences and explicitly authorised subjects. Game sign-in does not grant staff access.</p>`)+card('Known staff',pTable(['Name','Role','Last seen'],d.items.map(r=>[esc(r.display_name),esc(r.role),esc(date(r.last_seen_at))])));
 }
 if(tab==='releases'){
  const d=await api('releases');return head+card('Release registry',`${role==='owner'?'<button class="btn btn-primary" id="platform-release">Record a release</button>':''}`+pTable(['Build','Name','Stage','Revision','Compare'],d.items.map(r=>[esc(r.build_id),esc(r.name),esc(r.state),pNumber(r.revision),pLink('quality?build_id='+encodeURIComponent(r.build_id),'Inspect quality',params)])))+'<p>Registry stages record operational decisions. They do not deploy, publish or rewrite a race contract.</p>';
 }
 if(tab==='experiments'){
  const d=await api('experiments');return head+pNotice('Presentation changes only','Assignment remains stable. Count exposure only after a client applies its assigned setting. Physics, scoring, prices and purchase authority are excluded.')+
  card('Experiment registry',`${role==='owner'?'<button class="btn btn-primary" id="platform-experiment">Create experiment</button>':''}`+pTable(['Name','State','Follow-up','Minimum / variant','Actions'],d.items.map(r=>[esc(r.name),esc(r.state),r.followup_days+' days',pNumber(r.minimum_per_variant),`<button class="btn" data-scorecard="${r.id}">Scorecard</button>${role==='owner'&&r.state!=='stopped'?['active','paused','stopped'].filter(s=>s!==r.state&&!(r.state==='draft'&&s==='paused')).map(s=>`<button class="btn" data-experiment-state="${s}" data-id="${r.id}" data-revision="${r.revision}">${s==='active'?'Activate':s==='paused'?'Pause / roll back':'Stop'}</button>`).join(''):''}`])))+`<p>${esc(d.scope)}</p>`;
 }
 const d=await api('metrics');return head+card('Metric registry',pTable(['Measure','Definition & denominator','Source & population'],d.items.map(r=>[`<b>${esc(r.id)}</b><small>${esc(r.unit)}</small>`,`${esc(r.definition)}<small>${esc(r.denominator)}</small>`,`${esc(r.source)}<small>${esc(r.population)}</small>`])))+
 card('Observed source coverage',`<dl class="platform-definitions">${Object.entries(d.coverage).map(([k,v])=>`<dt>${esc(k.replaceAll('_',' '))}</dt><dd>${k.endsWith('_at')||k==='processed_through'?esc(date(v)):esc(v==null?'Unavailable':v)}</dd>`).join('')}</dl>`)+pLink('studio?tab=legacy','Detailed historical coverage',params);
}

function pCommand(title,fields,perform,actionLabel='Save'){
 modal(`<h2>${esc(title)}</h2><form id="platform-command">${fields}<p id="platform-command-error" class="console-error" hidden></p><div class="console-actions"><button class="btn" type="button" data-close>Cancel</button><button class="btn btn-primary" type="submit">${esc(actionLabel)}</button></div></form>`);
 const token=dialogToken();$('#platform-command').onsubmit=async e=>{e.preventDefault();const form=e.currentTarget,submit=form.querySelector('[type=submit]')||form.querySelector('button.btn-primary');submit.disabled=true;
  try{await perform(new FormData(form));if(!dialogIsCurrent(token))return;$('#dialog').close();await render();}
  catch(error){if(dialogIsCurrent(token)){$('#platform-command-error').hidden=false;$('#platform-command-error').textContent=error.message;if(error.detail?.current_policy&&error.desired_policy&&typeof gcDiff==='function')$('#platform-command-error').insertAdjacentHTML('beforeend','<p>Current server values compared with your proposed values. Reload and reconcile before saving.</p>'+gcDiff(error.detail.current_policy,error.desired_policy));submit.disabled=false;}}
 };
}
const pReason='<label>Reason<textarea name="reason" minlength="3" maxlength="500" required></textarea></label>';
function wirePlatform(params){
 wireRivalryCalendar(params);
 wireRanking();
 wireSavedReporting(params);
 document.querySelectorAll('[data-notification]').forEach(button=>button.onclick=()=>{const commandId=crypto.randomUUID();pCommand(button.dataset.notification==='retry'?'Retry stored notification':'Dismiss exhausted delivery',pReason,data=>api('notifications/'+button.dataset.id+'/commands',{command_id:commandId,expected_attempts:Number(button.dataset.attempts),action:button.dataset.notification,reason:data.get('reason')}));});
 document.querySelectorAll('[data-case-triage]').forEach(button=>button.onclick=async()=>{
  const current=JSON.parse(button.dataset.triage),staff=await api('staff'),commandId=crypto.randomUUID();
  pCommand('Assign case response',`<label>Owner<select name="assignee"><option value="">Unassigned</option>${staff.items.map(s=>`<option value="${esc(s.id)}" ${s.id===current.assignee?'selected':''}>${esc(s.display_name)}</option>`).join('')}</select></label><label>Priority<select name="priority">${['normal','high','urgent'].map(p=>`<option ${p===current.priority?'selected':''}>${p}</option>`).join('')}</select></label><label>Due date & time (UTC)<input name="due" type="datetime-local" value="${current.due_at?new Date(current.due_at*1000).toISOString().slice(0,16):''}"></label><label>Related incident ID<input name="incident_id" maxlength="36" value="${esc(current.incident_id||'')}"></label>`+pReason,data=>api('cases/'+button.dataset.caseTriage+'/triage',{command_id:commandId,expected_revision:current.revision,assignee:data.get('assignee'),priority:data.get('priority'),due_at:data.get('due')?Date.parse(data.get('due')+'Z')/1000:null,incident_id:data.get('incident_id')||null,reason:data.get('reason')}));
 });
 document.querySelectorAll('[data-incident]').forEach(button=>button.onclick=async()=>{
  const action=button.dataset.incident,identity=button.dataset.id,revision=Number(button.dataset.revision);
  let fields=pReason;
  if(action==='assign'){const d=await api('staff');fields='<label>Response owner<select name="assignee"><option value="">Unassigned</option>'+d.items.map(r=>`<option value="${esc(r.id)}">${esc(r.display_name)}</option>`).join('')+'</select></label>'+fields;}
  if(action==='suppress')fields='<label>Notification pause<select name="suppress_seconds"><option value="3600">1 hour</option><option value="14400">4 hours</option><option value="86400">24 hours</option><option value="0">Resume now</option></select></label>'+fields;
  const commandId=crypto.randomUUID();pCommand(action==='clear'?'Clear recovered issue':action,fields,data=>api('incidents/'+identity+'/commands',{command_id:commandId,expected_revision:revision,action,reason:data.get('reason'),assignee:data.get('assignee')||'',suppress_seconds:Number(data.get('suppress_seconds')||0)}));
 });
 if($('#platform-release'))$('#platform-release').onclick=()=>{const commandId=crypto.randomUUID();pCommand('Record a release','<label>Exact build ID<input name="build_id" maxlength="80" required></label><label>Release name<input name="name" maxlength="100" required></label><label>Stage<select name="state"><option>testing</option><option>canary</option><option>production</option><option>rolled_back</option></select></label><label>Current revision (0 for new)<input name="expected_revision" type="number" min="0" value="0" required></label><label>Notes<textarea name="notes" maxlength="500"></textarea></label>'+pReason,data=>api('releases',{...Object.fromEntries(data),command_id:commandId,expected_revision:Number(data.get('expected_revision'))}));};
 if($('#platform-experiment'))$('#platform-experiment').onclick=()=>{const commandId=crypto.randomUUID();pCommand('Create a presentation experiment','<label>Name<input name="name" maxlength="100" required></label><label>Control onboarding message<input name="control" maxlength="160" required></label><label>Variant onboarding message<input name="variant" maxlength="160" required></label><label>Follow-up days<input name="days" type="number" min="1" max="30" value="7" required></label><label>Minimum mature players per variant<input name="minimum" type="number" min="100" max="100000" value="500" required></label>'+pReason,data=>api('experiments',{command_id:commandId,name:data.get('name'),reason:data.get('reason'),primary_metric:'return_on_target_day',followup_days:Number(data.get('days')),minimum_per_variant:Number(data.get('minimum')),allocation:{control:5000,variant:5000},variants:{control:{onboarding_message:data.get('control')},variant:{onboarding_message:data.get('variant')}}}));};
 document.querySelectorAll('[data-experiment-state]').forEach(button=>button.onclick=()=>{const commandId=crypto.randomUUID();pCommand('Change experiment state',pReason,data=>api('experiments/'+button.dataset.id+'/state',{command_id:commandId,expected_revision:Number(button.dataset.revision),state:button.dataset.experimentState,reason:data.get('reason')}));});
 document.querySelectorAll('[data-scorecard]').forEach(button=>button.onclick=async()=>{const d=await api('experiments/'+button.dataset.scorecard+'/scorecard');modal('<h2>'+esc(d.experiment.name)+'</h2>'+pNotice('Decision: hold',d.decision)+pTable(['Variant','Exposed','Mature','Returned','Rate'],d.variants.map(r=>[esc(r.id),pNumber(r.exposed),pNumber(r.eligible),pNumber(r.returned),pPercent(r.returned,r.eligible)]))+`<p>Sample ratio check: ${d.sample_ratio.p_value==null?'Insufficient expected counts':d.sample_ratio.failed?'Mismatch detected':'No mismatch detected'} · p=${esc(d.sample_ratio.p_value)}</p><p>Crash-free and verified revenue guardrails are unavailable. No winner is declared automatically.</p>`);});
}

function wireSavedReporting(params){
 const keys=['since','until','build_id','baseline','platform','mode','population','tab','q','state','kind','failure_code','all','status','time_field','device_model','os_version','track_version_id','version','renderer','render_context_key','context_state','car_detail','category','metric','theme','visibility','origin','sort','direction','min_rating','min_finishers','limit','view','draft'];
 const save=$('#platform-save');if(save)save.onclick=()=>{
  const route=location.hash.slice(1).split('?')[0]||'overview',id=crypto.randomUUID(),commandId=crypto.randomUUID();
  const filters=Object.fromEntries([...params].filter(([key])=>keys.includes(key)));
  pCommand('Save this investigation location','<label>Name<input name="name" maxlength="100" required></label>',data=>api('saved-views',{command_id:commandId,id,expected_revision:0,name:data.get('name'),route,filters}));
 };
 document.querySelectorAll('[data-saved-rename]').forEach(button=>button.onclick=()=>{
  const saved=JSON.parse(button.dataset.savedRename),commandId=crypto.randomUUID();
  pCommand('Rename saved view',`<label>Name<input name="name" maxlength="100" value="${esc(saved.name)}" required></label>`,data=>api('saved-views',{command_id:commandId,id:saved.id,expected_revision:saved.revision,name:data.get('name'),route:saved.route,filters:saved.filters}));
 });
 document.querySelectorAll('[data-saved-delete]').forEach(button=>button.onclick=()=>{
  const saved=JSON.parse(button.dataset.savedDelete),commandId=crypto.randomUUID();
  pCommand('Delete saved view',`<p>Remove ${esc(saved.name)} from your saved locations.</p>`,()=>api('saved-views/'+saved.id+'/delete',{command_id:commandId,expected_revision:saved.revision}),'Delete view');
 });
 const button=$('#platform-export');if(!button)return;
 button.onclick=async()=>{
  const auth=authGeneration,page=generation,credential=key,view=button.dataset.view;
  const current=()=>auth===authGeneration&&page===generation&&credential===key;
  const fields=view==='releases'?['build_id','baseline','platform','device_model','os_version','track_version_id','render_context_key']:['build_id','platform','mode','population'];
  const q=pQuery(params,fields);if(view!=='releases')q.set('view',view);
  button.disabled=true;$('#platform-export-status').textContent='Preparing report…';
  try{
   const response=await fetch('/v1/admin/exports/'+(view==='releases'?'releases':'activity')+'.csv?'+q,{headers:{Authorization:'Bearer '+credential},signal:readController.signal});
   if(!current())return;
   if(!response.ok){let detail='Export could not be prepared.';try{const data=await response.json();if(typeof data.detail==='string')detail=data.detail;}catch{}throw Error(detail);}
   const blob=await response.blob();if(!current())return;
   const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='observed-'+view+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
   const shown=$('[data-report-watermark]')?.dataset.reportWatermark,downloaded=response.headers.get('X-BMT-Report-Watermark');
   $('#platform-export-status').textContent=shown&&downloaded&&shown!==downloaded?'Downloaded a newer source snapshot. Refresh to reconcile the screen; the CSV includes its source time.':'Report downloaded with query time, source watermark and filters.';
  }catch(error){if(current()&&error.name!=='AbortError')$('#platform-export-status').textContent='Export failed: '+error.message;}
  finally{if(current())button.disabled=false;}
 };
}

let rivalryCalendarState=null;
function rivalryDay(value){return new Date(value*1000).toISOString().slice(0,10);}
function rivalryMetrics(track){return `${track.theme} · ${track.rating_average==null?'Unrated':track.rating_average.toFixed(2)+' stars ('+track.rating_count+' votes)'} · ${track.verified_finishers.toLocaleString()} verified finishers`;}
function rivalryTrackList(tracks){return `<ol class="rivalry-track-list">${tracks.map(t=>`<li><strong>${esc(t.name)}</strong><small>${esc(rivalryMetrics(t))}</small></li>`).join('')}</ol>`;}
async function rivalryCalendar(params){
 const page=generation,data=await api('rivalry-plans?vehicle_id='+encodeURIComponent(params.get('vehicle_id')||'compact'));
 if(page!==generation)return '';
 rivalryCalendarState={data,page};
 return `<section class="rivalry-calendar" aria-label="Weekly Rivalry calendar"><div class="rivalry-calendar-header"><div><h2>Next four weeks</h2><p>${data.ready_weeks} / 4 weeks ready · Monday–Sunday UTC · five tracks each</p></div><label>Event car<select id="rivalry-vehicle">${data.vehicles.map(v=>`<option value="${esc(v)}" ${v===data.vehicle_id?'selected':''}>${esc(v)}</option>`).join('')}</select></label></div><p class="console-note">${esc(data.policy)}</p>${data.ready_weeks<4?`<div class="rivalry-plan-alert" role="status"><strong>The calendar needs attention.</strong><p>The worker fills missing weeks and repairs unavailable future tracks once a minute. At least five eligible tracks are required for this car.</p>${role==='owner'?'<button class="btn" id="rivalry-fill">Fill missing weeks now</button>':''}</div>`:''}<div class="rivalry-weeks">${data.weeks.map((week,index)=>`<article class="card rivalry-week"><header><span>WEEK ${index+1}</span><h3>${rivalryDay(week.week_start)} – ${rivalryDay(week.ends_at-1)}</h3><small>${esc(week.source==='manual'?'Edited in Studio':week.source==='repaired'?'Automatically repaired':week.source==='missing'?'Awaiting eligible tracks':'Automatically selected')}</small></header>${week.tracks.length?rivalryTrackList(week.tracks):'<p class="console-note">No complete line-up yet.</p>'}${week.unavailable_version_ids.length?'<p class="console-error">One or more tracks are no longer eligible. Replacement is needed.</p>':''}${role==='owner'&&week.editable?`<button class="btn rivalry-edit" data-rivalry-edit="${index}">Edit line-up</button>`:''}</article>`).join('')}</div>${data.current?`<details class="rivalry-current"><summary>Current week · ${rivalryDay(data.current.week_start)} · locked</summary>${rivalryTrackList(data.current.tracks)}<p class="console-note">Started weeks and existing group results retain their assigned tracks.</p></details>`:''}<details class="rivalry-history"><summary>Schedule change history</summary>${data.history.length?'<ul>'+data.history.map(h=>`<li><strong>${esc(h.reason)}</strong><small>${esc(date(h.created_at))} · ${esc(h.actor)} · ${esc(h.action)} · command ${esc(h.command_id)}</small></li>`).join('')+'</ul>':'<p class="console-note">No staff changes recorded.</p>'}</details></section>`;
}
function wireRivalryCalendar(params){
 const state=rivalryCalendarState;
 if(!state||state.page!==generation)return;
 const vehicle=$('#rivalry-vehicle');
 if(vehicle)vehicle.onchange=()=>{const q=new URLSearchParams(params);q.set('vehicle_id',vehicle.value);q.delete('offset');location.hash='competitions?'+q;};
 document.querySelectorAll('[data-rivalry-edit]').forEach(button=>button.onclick=()=>editRivalryWeek(state.data.weeks[Number(button.dataset.rivalryEdit)],state.data.vehicle_id));
 const fill=$('#rivalry-fill');
 if(fill)fill.onclick=()=>{const command_id=crypto.randomUUID();pCommand('Fill missing Rivalry weeks',pReason,data=>api('rivalry-plans/prepare',{command_id,reason:data.get('reason')}));};
}
function editRivalryWeek(week,vehicle){
 let selected=week.tracks.map(t=>({...t})),slot=0,searchGeneration=0;
 const command_id=crypto.randomUUID();
 modal(`<div class="rivalry-editor"><h2>Edit weekly line-up</h2><p>${rivalryDay(week.week_start)} – ${rivalryDay(week.ends_at-1)} UTC · ${esc(vehicle)}</p><p>Select a slot, then choose an eligible replacement.</p><div id="rivalry-selected"></div><form id="rivalry-search"><label>Find an eligible track<input name="q" maxlength="80" autocomplete="off"></label><button class="btn">Search tracks</button></form><div id="rivalry-candidates" aria-live="polite"></div><form id="rivalry-preview-form"><label>Recorded reason<textarea id="rivalry-reason" required minlength="3" maxlength="500"></textarea></label><p id="rivalry-edit-error" class="console-error" role="alert" hidden></p><div class="console-actions"><button class="btn" type="button" data-close>Cancel</button><button id="rivalry-preview" class="btn btn-primary">Preview changes</button></div></form></div>`);
 const token=dialogToken();let lastCandidates=null;
 function error(message){if(dialogIsCurrent(token)){$('#rivalry-edit-error').hidden=false;$('#rivalry-edit-error').textContent=message;}}
 function drawSelected(){
  $('#rivalry-selected').innerHTML=`<ol class="rivalry-slot-list">${selected.map((t,i)=>`<li class="${i===slot?'selected':''}"><button type="button" class="btn" data-rivalry-slot="${i}" aria-pressed="${i===slot}">Slot ${i+1}: ${esc(t.name)}</button><small>${esc(rivalryMetrics(t))}</small></li>`).join('')}</ol>`;
  document.querySelectorAll('[data-rivalry-slot]').forEach(b=>b.onclick=()=>{slot=Number(b.dataset.rivalrySlot);drawSelected();if(lastCandidates)drawCandidates(lastCandidates);});
 }
 function drawCandidates(data){
  lastCandidates=data;
  $('#rivalry-candidates').innerHTML=`<p class="console-note">Replacing slot ${slot+1}. ${esc(data.eligibility)}</p><ul class="rivalry-candidate-list">${data.items.map((t,i)=>`<li><div><strong>${esc(t.name)}</strong><small>${esc(rivalryMetrics(t))}</small></div><button type="button" class="btn" data-rivalry-pick="${i}" ${selected.some(s=>s.track_id===t.track_id)?'disabled':''}>${selected.some(s=>s.track_id===t.track_id)?'Selected':'Use track'}</button></li>`).join('')}</ul>${!data.items.length?'<p>No eligible tracks match this search.</p>':''}<div class="console-actions">${data.offset?'<button class="btn" type="button" id="rivalry-candidate-prev">Previous</button>':''}${data.next_offset!=null?'<button class="btn" type="button" id="rivalry-candidate-next">Next</button>':''}</div>`;
  document.querySelectorAll('[data-rivalry-pick]').forEach(b=>b.onclick=()=>{selected[slot]={...data.items[Number(b.dataset.rivalryPick)]};drawSelected();drawCandidates(data);});
  if($('#rivalry-candidate-prev'))$('#rivalry-candidate-prev').onclick=()=>search(Math.max(0,data.offset-50));
  if($('#rivalry-candidate-next'))$('#rivalry-candidate-next').onclick=()=>search(data.next_offset);
 }
 async function search(offset=0){
  const pending=++searchGeneration,q=$('#rivalry-search input').value;
  $('#rivalry-candidates').textContent='Loading eligible tracks…';
  try{const data=await api('rivalry-plans/candidates?'+new URLSearchParams({vehicle_id:vehicle,q,offset}));if(dialogIsCurrent(token)&&pending===searchGeneration)drawCandidates(data);}
  catch(e){if(e.name!=='AbortError')error(e.message);}
 }
 drawSelected();search();
 $('#rivalry-search').onsubmit=e=>{e.preventDefault();search();};
 $('#rivalry-preview-form').onsubmit=async e=>{
  e.preventDefault();const reason=$('#rivalry-reason').value.trim();
  if(reason.length<3){error('Enter a reason with at least three nonblank characters.');return;}
  const body={command_id,expected_revision:week.revision,version_ids:selected.map(t=>t.version_id),reason};
  $('#rivalry-preview').disabled=true;
  try{const preview=await api('rivalry-plans/'+week.id+'/preview',body);if(dialogIsCurrent(token))confirmRivalryWeek(week,body,preview);}
  catch(err){error(err.message);if(dialogIsCurrent(token))$('#rivalry-preview').disabled=false;}
 };
}
function confirmRivalryWeek(week,body,preview){
 modal(`<div class="rivalry-editor"><h2>Confirm weekly line-up</h2><p>Week of ${rivalryDay(preview.week_start)} UTC</p><ol class="rivalry-comparison">${preview.before.map((t,i)=>`<li><small>Slot ${i+1}</small><span>${esc(t.name)}</span><strong>→ ${esc(preview.after[i].name)}</strong></li>`).join('')}</ol><p>Reason: ${esc(body.reason)}</p><p class="console-note">The five tracks will be used when this future week starts. This choice stays saved during automatic planning.</p><p id="rivalry-command-error" class="console-error" role="alert" hidden></p><div class="console-actions"><button type="button" class="btn" data-close>Cancel</button><button class="btn btn-primary" id="rivalry-save">Save line-up</button></div></div>`);
 const token=dialogToken(),command={...body,preview_at:preview.preview_at,preview_hash:preview.preview_hash};
 $('#rivalry-save').onclick=async()=>{
  $('#rivalry-save').disabled=true;
  try{await api('rivalry-plans/'+week.id+'/commands',command);if(dialogIsCurrent(token)){$('#dialog').close();await render();}}
  catch(error){if(dialogIsCurrent(token)){$('#rivalry-command-error').hidden=false;$('#rivalry-command-error').textContent=error.message+(!error.status?' Retry sends the same saved command.':'');$('#rivalry-save').disabled=false;$('#rivalry-save').textContent='Retry saved line-up';}}
 };
}
