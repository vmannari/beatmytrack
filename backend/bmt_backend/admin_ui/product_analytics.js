'use strict';
function paCount(value,fallback='Unavailable'){
 return Number.isInteger(value)&&value>=0?value.toLocaleString('en-US'):fallback;
}
function paRatio(count,total){
 return Number.isInteger(count)&&Number.isInteger(total)&&total>0?(100*count/total).toFixed(1)+'%':null;
}
function paMetric(title,value,note,id){
 return `<div class="metric"><div class="metric-label">${esc(title)}</div><div class="metric-value" id="${id}">${esc(value)}</div><div class="metric-meta">${esc(note)}</div></div>`;
}
function paActivity(data){
 const max=Math.max(1,...data.daily.map(row=>Number.isInteger(row.active_players)?row.active_players:0));
 const bars=data.daily.map(row=>{
  const observed=row.observed&&Number.isInteger(row.active_players),label=row.day+': '+(observed?paCount(row.active_players)+' active players'+(row.current_partial?' · In progress':''):'Not observed');
  return `<div class="pa-day ${observed?'observed':'unobserved'}" aria-label="${esc(label)}" title="${esc(label)}"><div class="pa-day-value">${observed?paCount(row.active_players):'—'}</div><div class="pa-day-bar" style="height:${observed?Math.max(2,100*row.active_players/max):70}%"></div><span>${esc(row.day.slice(5))}${row.current_partial?'*':''}</span></div>`;
 }).join('');
 const table=`<div class="console-table"><table id="pa-daily-table"><thead><tr><th scope="col">UTC day</th><th scope="col">Observed active players</th><th scope="col">Accepted race submissions</th><th scope="col">Day status</th></tr></thead><tbody>${data.daily.map(row=>`<tr><th scope="row">${esc(row.day)}</th><td>${paCount(row.active_players,'Not observed')}</td><td>${paCount(row.accepted_races,'Not observed')}</td><td>${!row.observed?'Not observed':row.current_partial?'In progress':'Complete'}</td></tr>`).join('')}</tbody></table></div>`;
 return `<div class="pa-chart-scroll"><div class="pa-activity-chart" role="img" aria-label="Daily observed active players. Exact daily values are available in the evidence table." style="min-width:${Math.max(380,data.daily.length*40)}px">${bars}</div></div><p class="console-note">Daily distinct signed-in players with qualifying observed activity. Hatched days have no observation coverage; * marks an incomplete UTC day.</p><details class="studio-chart-data"><summary>View daily evidence table</summary>${table}</details>`;
}
function paFunnel(name,funnel,id,creatorValue=null,observedScope=true){
 const known=Number.isInteger(funnel.cohort_players),size=known?funnel.cohort_players:0;
 const unavailable=!observedScope?'Not observed':!funnel.mature?'Not mature':'Unavailable';
 const steps=funnel.steps.map((step,index)=>{
  const count=Number.isInteger(step.count)&&step.count>=0?step.count:null;
  const ratio=count==null?null:paRatio(count,size),width=count==null||size<=0?0:Math.min(100,100*count/size);
  const names={app_first_open:'First observed open',menu_ready:'Menu ready',race_attempt:'Race attempt',race_started:'Race started',race_finished:'Race finished',second_voluntary_race:'Second voluntary race',editor_opened:'Editor opened',draft_saved:'Draft saved',publish_requested:'Publication requested',track_published:'Track published'};
  return `<li><span class="pa-step-number">${index+1}</span><div class="pa-step-name">${esc(names[step.name]||step.name)}</div><div class="pa-funnel-track" aria-hidden="true"><div style="width:${width}%"></div></div><div class="pa-step-count">${paCount(count,unavailable)}<small>${esc(ratio||'')}</small></div></li>`;
 }).join('');
 const firstRace=id==='pa-first-race-funnel';
 const maturity=!known?unavailable:funnel.mature?(size>0?'Mature cohort':'No eligible cohort'):'No mature cohort';
 const seconds=funnel.second_race_followup_seconds;
 const secondWindow=Number.isInteger(seconds)&&seconds>0?(seconds%60===0?seconds/60+' minutes':seconds+' seconds'):null;
 const definition=firstRace?'First observed open, with 24 hours of follow-up. '+(secondWindow?'The second start follows the first finish within '+secondWindow+'; pre-finish retries are excluded. ':'')+'Race completion is a client observation; acceptance is counted separately.':'First observed editor open, with seven days of follow-up. Publication uses the server record.';
 const cohortLabel=known?paCount(funnel.cohort_players)+' cohort player'+(size===1?'':'s'):unavailable==='Not mature'?'Follow-up not mature':'Cohort '+unavailable.toLowerCase();
 const reachCount=!creatorValue||creatorValue.external_racer_7d_versions==null||creatorValue.mature_published_versions==null?'Not observed':creatorValue.mature_published_versions===0?'No mature published versions':paCount(creatorValue.external_racer_7d_versions)+' / '+paCount(creatorValue.mature_published_versions);
 const reach=creatorValue?`<div class="pa-published-reach"><h4>Published-track reach</h4><dl id="pa-creator-reach"><div><dt>Observed published versions</dt><dd>${paCount(creatorValue.published_versions,'Not observed')}</dd></div><div><dt>Complete ${esc(creatorValue.cohort_followup_days)}-day follow-up</dt><dd>${paCount(creatorValue.mature_published_versions,'Not observed')}</dd></div><div><dt>External accepted racer within ${esc(creatorValue.cohort_followup_days)} days</dt><dd>${reachCount}</dd></div></dl><p class="console-note">Published-version cohort; accepted ordinary races by another player.</p></div>`:'';
 return card(name,`<div class="pa-funnel-meta"><span>${esc(cohortLabel)}</span><span class="studio-coverage-state ${funnel.mature&&size>0?'supported':'partial'}">${maturity}</span></div><ol class="pa-funnel" id="${id}">${steps}</ol><p class="console-note">${definition} Steps are ordered; percentages use this cohort as the denominator.</p>${reach}`);
}
function paRetentionValue(cell){
 if(!cell.mature)return '<span class="pa-not-mature">Not mature</span>';
 if(cell.returned==null)return '<span class="pa-not-observed">Unavailable</span>';
 if(!cell.eligible)return '<span class="pa-not-observed">No eligible players</span>';
 const ratio=paRatio(cell.returned,cell.eligible);
 return `<strong>${esc(ratio||'Unavailable')}</strong><small>${paCount(cell.returned)} / ${paCount(cell.eligible)}</small>`;
}
function paRetention(rows){
 if(!rows.length)return '<p class="console-empty">No first-activity cohorts observed in this window.</p>';
 return `<p class="console-note">Exact-day return after first observed qualifying activity. Only complete target UTC days are mature; missing coverage is not a zero return.</p><div class="console-table"><table id="pa-retention-table"><thead><tr><th scope="col">First observed activity</th><th scope="col">Cohort players</th><th scope="col">Exact D1</th><th scope="col">Exact D7</th></tr></thead><tbody>${rows.map(row=>`<tr><th scope="row">${esc(row.cohort_day)}</th><td>${paCount(row.cohort_players)}</td><td>${paRetentionValue(row.d1)}</td><td>${paRetentionValue(row.d7)}</td></tr>`).join('')}</tbody></table></div>`;
}
function paChoices(rows,id,subject){
 if(!rows.length)return `<p class="console-empty">No ${esc(subject)} exposure or selection observations in this window.</p>`;
 return `<div class="console-table"><table id="${id}"><thead><tr><th scope="col">${esc(subject)}</th><th scope="col">Exposure events</th><th scope="col">Selection events</th></tr></thead><tbody>${rows.map(row=>`<tr><th scope="row">${esc(row.id)}</th><td>${paCount(row.exposures)}</td><td>${paCount(row.selections)}</td></tr>`).join('')}</tbody></table></div><p class="console-note">Recorded offer exposures and selections, not unique players or causal preference.</p>`;
}
function paStore(store){
 if(!store)return '<p class="console-empty">Store observations are unavailable.</p>';
 const offers=store.offers.length?`<div class="console-table"><table id="pa-store-offers"><thead><tr><th scope="col">Offer</th><th scope="col">Exposure events</th><th scope="col">Purchase request events</th></tr></thead><tbody>${store.offers.map(offer=>`<tr><th scope="row">${esc(offer.id)}</th><td>${paCount(offer.exposures,'Not observed')}</td><td>${paCount(offer.requests,'Not observed')}</td></tr>`).join('')}</tbody></table></div>`:'<p class="console-empty">No offer observations in this window.</p>';
 return `<dl class="pa-action-counts"><div><dt>Store opens</dt><dd id="pa-store-opened">${paCount(store.opened,'Not observed')}</dd></div></dl>${offers}<p class="console-note">Client observations. Verified payment, fulfillment and revenue are unavailable.</p>`;
}
function paSocial(challenges){
 const labels=[['challenge_opened','Challenge opens'],['challenge_joined','Challenge join events'],['challenge_created','Challenge creation events'],['share_clicked','Share clicks']];
 return `<dl class="pa-action-counts" id="pa-social-counts">${labels.map(([key,label])=>`<div><dt>${label}</dt><dd data-social-metric="${key}">${paCount(challenges?.[key],'Not observed')}</dd></div>`).join('')}</dl><p class="console-note">Client observations, not distinct participants or authoritative challenge membership.</p>`;
}
function paQuality(quality){
 const labels=[['dropped_events','Reported dropped events'],['rejected_events','Reported rejected events'],['persistence_failures','Reported persistence failures']];
 return `<dl class="pa-loss-summary" id="pa-collection-loss">${labels.map(([key,label])=>`<div><dt>${label}</dt><dd data-quality-metric="${key}">${paCount(quality?.[key],'Not observed')}</dd></div>`).join('')}</dl><p class="console-note">Per-player maximum reports; shared installations and account changes can overlap.</p>`;
}
function productAnalyticsView(data){
 const coverage=data.coverage,latest=data.daily.at(-1);
 const observedScope=data.daily.some(row=>row.observed);
 const latestNote=latest?latest.day+' UTC'+(!latest.observed?' · Not observed':latest.current_partial?' · In progress':' · Complete day'):'No observed days';
 const utcDay=value=>new Date(value*1000).toISOString().slice(0,10);
 const weekNote=data.weekly_since!=null&&data.weekly_until!=null?utcDay(data.weekly_since)+' – '+utcDay(data.weekly_until-1)+' UTC':'Distinct signed-in players';
 const pending=(coverage.pending_events_capped?'≥ ':'')+paCount(coverage.pending_events);
 const metrics=`<div class="metrics four pa-metrics">${paMetric('Latest daily active players',paCount(latest?.active_players,'Not observed'),latestNote,'pa-dau')}${paMetric('7-day active players',paCount(data.weekly_active_players,'Not observed'),weekNote,'pa-wau')}${paMetric('Active players in selected window',paCount(data.period_active_players,'Not observed'),'Distinct signed-in players','pa-period-active')}${paMetric('Events awaiting projection',pending,coverage.pending_events_capped?'Queue count is a lower bound':'New evidence may still be processing','pa-pending')}</div>`;
 const retention=coverage.fact_retention_days!=null?`<div><dt>Reporting retention</dt><dd>${paCount(coverage.fact_retention_days)} days${coverage.retained_from!=null?' · From '+esc(utcDay(coverage.retained_from)):''}</dd></div>`:'';
 const scope=`<div class="studio-scope pa-scope" id="pa-coverage"><p>${esc(coverage.scope)}</p><dl><div><dt>Collection began</dt><dd>${coverage.collection_started_at==null?'Not started':esc(date(coverage.collection_started_at))}</dd></div><div><dt>Processed through</dt><dd>${coverage.processed_through==null?'No projected observations':esc(date(coverage.processed_through))}</dd></div><div><dt>Latest receipt</dt><dd>${coverage.latest_receipt_at==null?'No acknowledged batches':esc(date(coverage.latest_receipt_at))}</dd></div>${retention}</dl></div>`;
 const limits=`<ul class="studio-limits">${coverage.limitations.filter(value=>!value.startsWith('Loss counters are client-reported')).map(value=>`<li>${esc(value)}</li>`).join('')}</ul>`;
 const disabled=data.telemetry_enabled===false?'<p class="console-error" role="status">Product telemetry is disabled on this backend. Retained observations, if present, do not establish current activity coverage.</p>':'';
 return intro('Product analytics','Observed signed-in activity, ordered journeys and exact-day returns.','LEARN')+disabled+scope+metrics+
  card('Observed activity',paActivity(data))+
  `<div class="console-grid pa-funnels">${paFunnel('First-race journey',data.funnels.first_race,'pa-first-race-funnel',null,observedScope)}${paFunnel('Creator journey',data.funnels.creator,'pa-creator-funnel',data.creator_value,observedScope)}</div>`+
  card('Exact-day retention',paRetention(data.retention))+
  `<div class="console-grid">${card('Car exposure & selection',paChoices(data.preferences.cars,'pa-car-choices','Car'))}${card('Biome exposure & selection',paChoices(data.preferences.biomes,'pa-biome-choices','Biome'))}</div>`+
  `<div class="console-grid">${card('Observed Store actions',paStore(data.store))}${card('Social & challenges',paSocial(data.challenges))}</div>`+
  card('Reported collection loss',paQuality(data.quality))+
  card('Metric coverage',limits);
}
