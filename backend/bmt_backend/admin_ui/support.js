'use strict';
let supportCurrent = null;
const supportBack = new Map();
const accessLabels = {slots:'Account slots remaining', simulated_slots:'Simulated slots remaining',
  ad_free_until:'Account monthly access until', simulated_ad_free_until:'Simulated monthly access until',
  forever:'Account permanent access', simulated_forever:'Simulated permanent access'};
function accessTable(values) {
  return `<dl>${Object.entries(values).map(([name,value])=>`<div class="console-kv"><dt>${esc(accessLabels[name] || name)}</dt><dd>${name.endsWith('_until') ? esc(date(value)) : esc(value)}</dd></div>`).join('')}</dl>`;
}
function supportQuery(params) {
  const query = new URLSearchParams();
  for (const field of ['kind','q','state','cursor','since','until','all']) if (params.get(field)) query.set(field, params.get(field));
  return query;
}
function historyScope(id, params) {
  const query = supportQuery(params); query.delete('cursor');
  return id + '?' + query;
}
function supportHref(id, query) { return '#players/' + encodeURIComponent(id) + '?' + query; }
function activitySummary(item) {
  const row = item.record;
  if (item.kind === 'purchase') return `${row.product_id} · ${row.simulated ? 'Simulation' : row.provider}`;
  if (item.kind === 'publication') return `Publishing slot consumed · ${row.source}`;
  if (item.kind === 'resume') return `Resume ${row.ordinal} · ${row.source}`;
  if (item.kind === 'grant') return `${row.quantity} resumes · ${row.source}`;
  if (item.kind === 'race') return row.failure_code || 'Race submission';
  if (item.kind === 'audit' && row.action === 'player_grant') return `Granted ${row.after.title} × ${row.after.quantity}`;
  return row.action.replaceAll('_',' ');
}
async function supportWorkspace(id, params) {
  const renderGeneration = generation;
  const query = supportQuery(params);
  const [data,history] = await Promise.all([api(`players/${encodeURIComponent(id)}/support`),
    api(`players/${encodeURIComponent(id)}/history?${query}`)]);
  if (renderGeneration === generation) supportCurrent = {id,data,history,params:new URLSearchParams(params)};
  const player = data.player, controls = data.development_controls;
  const pendingControls = controls.editable;
  const selector = (name,values) => `<select name="${name}">${values.map(([value,label])=>`<option value="${value}" ${(params.get(name)||'')===value?'selected':''}>${label}</option>`).join('')}</select>`;
  const actions = pendingControls ? `<div class="console-actions"><button class="btn btn-primary" data-support-action="simulate_purchase">Simulate purchase</button><button class="btn" data-support-action="adjust_slots">Adjust slots</button><button class="btn" data-support-action="expire_month">Expire simulated month</button><button class="btn" data-support-action="reset_ad_free">Reset simulated ad-free</button></div>` :
    `<p class="console-note">${controls.role!=='owner'?'Read-only access.':!controls.configured?'Purchase simulation is disabled on this backend.':'This account is not eligible for development purchases.'}</p>`;
  const access = `<div class="metrics four">${metric('Publishing slots remaining',data.effective.publishing_slots,'players/'+id)}${metric('Slots consumed',data.consumed_publication_slots,'players/'+id+'?kind=publication&all=1')}${metric('Banked resumes',data.resumes.banked,'players/'+id+'?kind=resume&all=1')}${metric('Pending purchases',data.pending_purchases,'players/'+id+'?kind=purchase&state=pending&all=1')}</div>`;
  const rows = history.items.map((item,index)=>{
    const row = item.record;
    const href = item.kind==='race'?scopedHref('races/'+encodeURIComponent(item.id),params):item.kind==='publication'?scopedHref('tracks/'+encodeURIComponent(item.id),params):null;
    return `<tr><td>${esc(date(item.created_at))}</td><td>${esc(item.kind)}</td><td>${esc(activitySummary(item))}<br><small>${href?`<a href="${href}">${esc(item.id)}</a>`:esc(item.id)}</small></td><td>${status(row.state||row.status||(item.kind==='resume'?(row.refunded?'refunded':row.settled?'settled':'pending'):''))}</td><td><button class="btn" data-history-detail="${index}">Inspect</button>${pendingControls&&item.kind==='purchase'&&row.simulated&&row.state==='pending'?` <button class="btn" data-resolve-purchase="${index}">Resolve</button>`:''}</td></tr>`;
  }).join('');
  const back = supportBack.get(historyScope(id, params)) || [];
  const historyPanel = `<form id="support-filters" class="console-toolbar"><label>Activity${selector('kind',[['','All activity'],['purchase','Purchases'],['publication','Published slots'],['resume','Resume receipts'],['grant','Resume grants'],['race','Races'],['audit','Administrative changes']])}</label><label>Find<input name="q" maxlength="100" value="${esc(params.get('q')||'')}" placeholder="Purchase, race, command or request ID"></label><label>State${selector('state',[['','All states'],...['pending','approved','declined','cancelled','queued','verifying','verified','rejected','failed'].map(s=>[s,s])])}</label><button class="btn">Apply</button><button class="btn" id="support-clear" type="button">All time</button><button class="btn" id="support-export" type="button">Export page</button></form>${query.has('since')?`<p class="console-note">${esc(date(Number(query.get('since'))))} to ${esc(date(Number(query.get('until'))))} (end excluded)</p>`:''}<div class="console-table"><table><thead><tr><th>Time</th><th>Activity</th><th>Record</th><th>State</th><th>Actions</th></tr></thead><tbody>${rows}</tbody></table>${rows?'':'<p class="console-empty">No matching activity.</p>'}</div><div class="console-pager"><span>${history.items.length} records on this page</span><button class="btn" id="support-previous" ${params.get('cursor')&&back.length?'':'disabled'}>Previous</button><button class="btn" id="support-next" ${history.next_cursor?'':'disabled'}>Next</button></div>`;
  const profile = kv({player_id:id, player_type:playerType(player.is_test_driver), country:player.country_code||null, providers:player.providers,
    account:player.deleted_at?'removed':player.disabled?'restricted':'active', created_at:player.created_at,
    ad_free: data.effective.ad_free_forever?'Permanent':data.effective.ad_free?date(data.effective.ad_free_until):'Inactive',
    daily_free_resume:data.resumes.daily_free_available?'Available':'Used today'});
  return intro(player.display_name,'Player support') + `<div class="console-actions"><a class="btn" href="${scopedHref('players',params)}">← Players</a><a class="btn" href="${scopedHref('economy?player_id='+encodeURIComponent(id),params)}">Inspect this player's purchases</a>${role==='owner'&&!player.deleted_at?`<button class="btn" id="command" data-kind="players" data-id="${esc(id)}" data-value="${player.disabled}">${player.disabled?'Restore account':'Restrict account'}</button>`:''}</div>` + access +
    `<div class="console-grid">${card('Account & current access',profile)}${card('Purchase access',accessTable(data.access)+actions)}</div>` + card('Activity & evidence',historyPanel);
}
function wireSupport() {
  if (!$('#support-filters') || !supportCurrent) return;
  const {id,data,history,params} = supportCurrent;
  $('#support-filters').onsubmit = event => {
    event.preventDefault(); const query=supportQuery(params); query.delete('cursor');
    for (const [name,value] of new FormData(event.target)) value?query.set(name,value):query.delete(name);
    location.hash=supportHref(id,query);
  };
  $('#support-clear').onclick=()=>{const query=supportQuery(params);for(const name of ['since','until','cursor'])query.delete(name);query.set('all','1');location.hash=supportHref(id,query);};
  $('#support-next').onclick=()=>{const scope=historyScope(id,params),back=supportBack.get(scope)||[];back.push(params.get('cursor')||'');supportBack.set(scope,back);const query=supportQuery(params);query.set('cursor',history.next_cursor);location.hash=supportHref(id,query);};
  $('#support-previous').onclick=()=>{const back=supportBack.get(historyScope(id,params))||[],query=supportQuery(params),previous=back.pop();previous?query.set('cursor',previous):query.delete('cursor');location.hash=supportHref(id,query);};
  $('#support-export').onclick=async()=>{
    const button=$('#support-export'),pageGeneration=generation,auth=authGeneration;button.disabled=true;
    try{const query=supportQuery(params);query.set('download','true');const exported=await api(`players/${encodeURIComponent(id)}/history?${query}`);
      if(pageGeneration!==generation||auth!==authGeneration)return;
      const url=URL.createObjectURL(new Blob([JSON.stringify(exported,null,2)],{type:'application/json'})),link=document.createElement('a');link.href=url;link.download='player-history.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
    }catch(error){if(pageGeneration!==generation||auth!==authGeneration||error.name==='AbortError')return;modal(`<h2>Export unavailable</h2><p>${esc(error.message)}</p><button class="btn" data-close>Close</button>`);}finally{if(pageGeneration===generation&&auth===authGeneration)button.disabled=false;}
  };
  document.querySelectorAll('[data-history-detail]').forEach(button=>button.onclick=()=>{const item=history.items[Number(button.dataset.historyDetail)];modal(`<h2>Activity evidence</h2>${kv(item.record)}<button class="btn" data-close>Close</button>`);});
  document.querySelectorAll('[data-resolve-purchase]').forEach(button=>button.onclick=()=>developmentCommand(id,data,'resolve_purchase',history.items[Number(button.dataset.resolvePurchase)].record));
  document.querySelectorAll('[data-support-action]').forEach(button=>button.onclick=()=>developmentCommand(id,data,button.dataset.supportAction));
}
function developmentCommand(id,data,action,purchase=null) {
  const titles={simulate_purchase:'Simulate purchase',resolve_purchase:'Resolve pending purchase',adjust_slots:'Adjust remaining simulated slots',expire_month:'Expire simulated monthly access',reset_ad_free:'Reset simulated ad-free access'};
  let fields='';
  if(action==='simulate_purchase')fields=`<label>Product<select id="dev-product">${data.products.filter(p=>p.enabled).map(p=>`<option value="${esc(p.id)}">${esc(p.title)}</option>`).join('')}</select></label>`;
  if(action==='simulate_purchase'||action==='resolve_purchase')fields+=`<label>Outcome<select id="dev-outcome">${(action==='simulate_purchase'?['pending','approved','declined','cancelled']:['approved','declined','cancelled']).map(value=>`<option>${value}</option>`).join('')}</select></label>`;
  if(action==='adjust_slots')fields='<label>Change in remaining slots<input id="dev-slots" type="number" step="1" min="-1000" max="1000" value="1" required></label>';
  modal(`<h2>${titles[action]}</h2>${purchase?kv({purchase_id:purchase.id,product:purchase.product_id}):''}<form id="dev-draft">${fields}<p id="dev-error" class="console-error" hidden></p><div class="console-actions"><button class="btn" type="button" data-close>Cancel</button><button class="btn btn-primary" id="dev-preview">Preview change</button></div></form>`);
  const token=dialogToken();
  $('#dev-draft').onsubmit=async event=>{
    event.preventDefault();const button=$('#dev-preview');button.disabled=true;
    const draft={command_id:crypto.randomUUID(),action};
    if(action==='simulate_purchase')draft.product_id=$('#dev-product')?.value;
    if(action==='simulate_purchase'||action==='resolve_purchase')draft.outcome=$('#dev-outcome').value;
    if(action==='resolve_purchase')draft.purchase_id=purchase.id;
    if(action==='adjust_slots')draft.slots_delta=Number($('#dev-slots').value);
    try{const preview=await api(`players/${encodeURIComponent(id)}/development/preview`,draft);if(!dialogIsCurrent(token))return;confirmDevelopment(id,draft,preview,titles[action]);}
    catch(error){if(!dialogIsCurrent(token))return;$('#dev-error').hidden=false;$('#dev-error').textContent=error.message;button.disabled=false;}
  };
}

function playerGrants(id,data,params) {
  const grants=data.grants, products=new Map(grants.products.map(p=>[p.id,p]));
  const owned=grants.owned.map(item=>`<li><strong>${esc(products.get(item)?.title||item)}</strong><small class="stc-id">${esc(item)}</small></li>`).join('');
  return `<h3>Purchases &amp; grants</h3><div class="stc-access-grid">${catalogueStat('Track slots remaining',data.effective.publishing_slots,'Available for publication')}${catalogueStat('Owned customisations',grants.owned.length,'Kits and liveries')}${catalogueStat('Banked resumes',data.resumes.banked,'Permanent balance')}${catalogueStat('Coins',grants.coin_balance,'Current earned balance')}</div><dl class="stc-facts"><div><dt>Ad-free access</dt><dd>${data.effective.ad_free_forever?'Permanent':data.effective.ad_free?'Until '+esc(date(data.effective.ad_free_until)):'Inactive'}</dd></div></dl><div class="console-actions">${grants.editable?'<button class="btn btn-primary" id="player-grant">Grant an item</button>':`<p class="console-note">${role==='owner'?'Restore this account before granting items.':'Owner access is required to grant items.'}</p>`}<a class="btn" href="${scopedHref('economy?player_id='+id,params)}">Purchase records</a><a class="btn" href="${catalogueHref('players/'+id,params,{tab:'timeline',kind:'audit',all:'1',since:null,until:null,cursor:null,q:'player_grant',state:null})}">Grant audit history</a></div><p class="console-note">Support grants add account access without charging the player. Store payments remain in purchase records.</p><h4>Owned kits &amp; liveries</h4>${owned?`<ul class="stc-owned-items">${owned}</ul>`:'<p class="console-empty">No kits or liveries unlocked.</p>'}`;
}
function wirePlayerGrants() {
  const button=$('#player-grant');
  if(button&&supportCurrent)button.onclick=()=>playerGrantCommand(supportCurrent.id,supportCurrent.data);
}
function playerGrantError(error) {
  return ({STATE_CHANGED_REFRESH_REQUIRED:'This player’s access changed. Close and preview the grant again.',
    PREVIEW_EXPIRED_REFRESH_REQUIRED:'This preview expired. Close and preview the grant again.',
    COSMETIC_ALREADY_OWNED:'This player already owns that item.',
    ALREADY_AD_FREE_FOREVER:'This player already has permanent ad-free access.',
    PLAYER_NOT_ELIGIBLE_FOR_GRANT:'This account is restricted or removed. Refresh the player view.',
    GRANT_CAPACITY_EXCEEDED:'This grant would exceed the account balance limit.',
    OWNER_REQUIRED:'Owner access is required to grant items.',REASON_REQUIRED:'Enter a reason with at least eight nonblank characters.'})[error.message]||error.message;
}
function playerGrantCommand(id,data) {
  const available=data.grants.products.filter(p=>!data.grants.owned.includes(p.id)), draft={command_id:crypto.randomUUID()};
  modal(`<h2>Grant an item</h2><p><strong>${esc(data.player.display_name)}</strong><small class="stc-id">${esc(id)}</small></p><form id="grant-draft"><label>Find an item<input id="grant-search" type="search" placeholder="Track slots, kit, livery, ad-free or resumes" maxlength="100"></label><label>Item<select id="grant-product" required></select></label><label>Quantity<input id="grant-quantity" type="number" min="1" max="1000" step="1" value="1" required></label><p id="grant-error" class="console-error" role="alert" hidden></p><div class="console-actions"><button class="btn" type="button" data-close>Cancel</button><button class="btn btn-primary" id="grant-preview">Preview grant</button></div></form>`);
  const token=dialogToken(), select=$('#grant-product'), quantity=$('#grant-quantity');
  function updateQuantity(){const item=available.find(p=>p.id===select.value);quantity.max=item?.max_quantity||1;quantity.disabled=!item||item.max_quantity===1;if(quantity.disabled||Number(quantity.value)>Number(quantity.max))quantity.value='1';$('#grant-preview').disabled=!item;}
  function options(){const selected=select.value,query=$('#grant-search').value.trim().toLowerCase(),items=available.filter(p=>(p.title+' '+p.group+' '+p.id).toLowerCase().includes(query));const groups=[...new Set(items.map(p=>p.group))];select.innerHTML=groups.map(group=>`<optgroup label="${esc(group)}">${items.filter(p=>p.group===group).map(p=>`<option value="${esc(p.id)}">${esc(p.title)}</option>`).join('')}</optgroup>`).join('');if(items.some(p=>p.id===selected))select.value=selected;updateQuantity();}
  options();select.onchange=updateQuantity;$('#grant-search').oninput=options;
  $('#grant-draft').onsubmit=async event=>{
    event.preventDefault();draft.product_id=select.value;draft.quantity=Number(quantity.value);$('#grant-preview').disabled=true;$('#grant-error').hidden=true;
    try{const preview=await api(`players/${encodeURIComponent(id)}/grants/preview`,draft);if(dialogIsCurrent(token))confirmPlayerGrant(id,draft,preview);}
    catch(error){if(!dialogIsCurrent(token))return;$('#grant-error').hidden=false;$('#grant-error').textContent=playerGrantError(error);updateQuantity();}
  };
}
function confirmPlayerGrant(id,draft,preview) {
  const labels={...accessLabels,slots:'Track slots remaining',banked_resumes:'Banked resumes',owned:'Item owned'};
  const display=(field,value)=>field.endsWith('_until')?date(value):typeof value==='boolean'?(value?'Yes':'No'):value;
  const changed=Object.keys(preview.after).filter(field=>preview.before[field]!==preview.after[field]&&field!=='wallet_revision');
  modal(`<h2>Confirm grant</h2><p><strong>${esc(preview.player.display_name)}</strong><small class="stc-id">${esc(id)}</small></p><p>${esc(preview.product.title)} &times; ${esc(preview.quantity)}</p><div class="console-table player-grant-comparison"><table><thead><tr><th>Access</th><th>Before</th><th>After</th></tr></thead><tbody>${changed.map(field=>`<tr><td>${esc(labels[field]||field)}</td><td>${esc(display(field,preview.before[field]))}</td><td>${esc(display(field,preview.after[field]))}</td></tr>`).join('')}</tbody></table></div><form id="grant-confirm"><label>Recorded reason<textarea id="grant-reason" required minlength="8" maxlength="500"></textarea></label><label><input id="grant-acknowledged" type="checkbox" required> Grant this item to the player shown above.</label><p id="grant-error" class="console-error" role="alert" hidden></p><div class="console-actions"><button class="btn" type="button" data-close>Cancel</button><button class="btn btn-primary" id="grant-submit">Confirm grant</button></div></form>`);
  const token=dialogToken();let command=null;
  $('#grant-confirm').onsubmit=async event=>{
    event.preventDefault();$('#grant-submit').disabled=true;$('#grant-error').hidden=true;
    const reason=$('#grant-reason').value.trim();
    if(!command&&reason.length<8){$('#grant-error').hidden=false;$('#grant-error').textContent='Enter a reason with at least eight nonblank characters.';$('#grant-submit').disabled=false;return;}
    command??={...draft,preview_at:preview.preview_at,expected_hash:preview.expected_hash,reason,acknowledged:true};
    $('#grant-reason').disabled=true;$('#grant-acknowledged').disabled=true;
    try{await api(`players/${encodeURIComponent(id)}/grants/commands`,command);if(!dialogIsCurrent(token))return;$('#dialog').close();render();}
    catch(error){if(!dialogIsCurrent(token))return;$('#grant-error').hidden=false;$('#grant-error').textContent=playerGrantError(error);$('#grant-submit').disabled=[403,409,422].includes(error.status);$('#grant-submit').textContent='Retry same grant';}
  };
}
function confirmDevelopment(id,draft,preview,title) {
  const changed=Object.keys(preview.after.access).filter(field=>preview.before.access[field]!==preview.after.access[field]);
  const changes=changed.length?`<table><thead><tr><th>Access</th><th>Before</th><th>After</th></tr></thead><tbody>${changed.map(field=>`<tr><td>${esc(accessLabels[field])}</td><td>${esc(field.endsWith('_until')?date(preview.before.access[field]):preview.before.access[field])}</td><td>${esc(field.endsWith('_until')?date(preview.after.access[field]):preview.after.access[field])}</td></tr>`).join('')}</tbody></table>`:'<p>No access is granted by this outcome.</p>';
  modal(`<h2>${esc(title)} · Preview</h2>${preview.after.purchase?kv(preview.after.purchase):''}${changes}<form id="dev-confirm"><label>Recorded reason<textarea id="dev-reason" minlength="8" maxlength="500" required></textarea></label><label><input type="checkbox" required> Apply this development change to the selected player.</label><p id="dev-error" class="console-error" hidden></p><div class="console-actions"><button class="btn" type="button" data-close>Cancel</button><button class="btn btn-primary" id="dev-submit">Confirm change</button></div></form>`);
  const token=dialogToken();
  const body={...draft,preview_at:preview.preview_at,expected_hash:preview.expected_hash,acknowledged:true};
  let submitted=false;
  $('#dev-confirm').onsubmit=async event=>{
    event.preventDefault();const button=$('#dev-submit');button.disabled=true;
    if(!submitted){body.reason=$('#dev-reason').value;submitted=true;$('#dev-reason').readOnly=true;}
    try{await api(`players/${encodeURIComponent(id)}/development/commands`,body);if(!dialogIsCurrent(token))return;$('#dialog').close();await render();}
    catch(error){if(!dialogIsCurrent(token))return;$('#dev-error').hidden=false;$('#dev-error').textContent=error.message;
      if(['STATE_CHANGED_REFRESH_REQUIRED','PREVIEW_EXPIRED_REFRESH_REQUIRED','PRODUCT_DISABLED','PURCHASE_ALREADY_RESOLVED'].includes(error.message)){$('#dev-error').textContent+=' Close and preview again.';}else{button.disabled=false;button.textContent='Retry same change';}}
  };
}
