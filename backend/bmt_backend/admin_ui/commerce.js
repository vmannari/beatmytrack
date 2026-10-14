'use strict';
const commerceBack=new Map();
let commerceCurrent=null,commerceAuth=-1;
function playerCommerce(id, entitlements) {
  return card('Purchases & access', `<p><a class="btn" href="#economy?player_id=${encodeURIComponent(id)}">Inspect this player's purchases</a></p>${entitlements ? kv(entitlements) : ''}<p class="console-note">Simulated balances are separate from verified store entitlements. Availability changes never revoke owned access.</p>`);
}
async function commercePage(params) {
  const current=generation,auth=authGeneration;
  if(commerceAuth!==auth){commerceBack.clear();commerceAuth=auth;commerceCurrent=null;}
  const query = new URLSearchParams();
  for (const field of ['player_id', 'state', 'provider', 'cursor', 'q', 'since', 'until']) if (params.get(field)) query.set(field, params.get(field));
  const [catalog, orders] = await Promise.all([api('products'), api('purchases?' + query)]);
  const scopeQuery=new URLSearchParams(query);scopeQuery.delete('cursor');scopeQuery.sort();
  const scope=scopeQuery.toString(),back=commerceBack.get(scope)||[];
  if(current===generation&&auth===authGeneration)commerceCurrent={scope,params:new URLSearchParams(params),orders,generation:current,auth};
  const option = (name, value, label) => `<option value="${value}" ${params.get(name) === value ? 'selected' : ''}>${label}</option>`;
  const controls = `<div class="console-table commerce-catalogue-table"><table><thead><tr><th>Product / contract</th><th>Proposed test EUR price</th><th>Availability</th><th>Revision</th><th>Owner action</th></tr></thead><tbody>${catalog.items.map(p => `<tr><td><strong>${esc(p.title)}</strong><small class="mon-id">${esc(p.id)}</small></td><td>€${esc(p.price_eur)}<small>Not verified player spend</small></td><td>${status(p.enabled ? 'enabled' : 'disabled')}</td><td>${p.revision}</td><td>${catalog.editable ? `<button class="btn" data-product="${esc(p.id)}" data-enabled="${p.enabled}" data-revision="${p.revision}">${p.enabled ? 'Disable' : 'Enable'}</button>` : 'Read only'}</td></tr>`).join('')}</tbody></table></div><p class="mon-caption">Owner-only development / test catalogue controls. Disabling blocks new checkout; accepted pending records and existing access remain valid. This does not connect real billing or reverse an entitlement.</p>`;
  const rows = orders.items.map(p => `<tr><td><strong>${esc(p.product_id)}</strong>${p.test_adjustment ? '<small>Development adjustment</small>' : ''}<small class="mon-id">${esc(p.id)}</small></td><td>${link('players', p.player_id,'Inspect player')}<small class="mon-id">${esc(p.player_id)}</small></td><td>${esc(p.simulated ? 'Simulation · no payment' : p.provider)}<small>${p.simulated?'Excluded from all spend / revenue':'Recorded provider; amount / currency feed unavailable'}</small></td><td>${status(p.state)}</td><td>${esc(date(p.created_at))}</td><td>${p.fulfilled_at?esc(date(p.fulfilled_at)):'No fulfillment recorded'}</td></tr>`).join('');
  const window=params.has('since')?date(Number(params.get('since')))+' to '+date(Number(params.get('until')))+' · end excluded':'All retained purchase dates';
  const purchases = `<form id="purchase-filters" class="stc-filters"><label>Player ID<input name="player_id" maxlength="36" value="${esc(params.get('player_id') || '')}" placeholder="Exact player UUID"></label><label class="stc-search">Find record<input name="q" maxlength="100" value="${esc(params.get('q')||'')}" placeholder="Purchase record or product ID"></label><label>State<select name="state">${option('state', '', 'All states')}${['approved','pending','declined','cancelled'].map(s => option('state', s, s)).join('')}</select></label><label>Provider<select name="provider">${option('provider', '', 'All providers')}${option('provider', 'simulation', 'Simulation')}${option('provider', 'google_play', 'Google Play')}</select></label><button class="btn btn-primary">Apply filters</button></form><p class="mon-caption">${esc(window)}. States describe server records, not settled receipts.</p><div class="console-table commerce-history-table"><table><thead><tr><th>Purchase evidence</th><th>Player</th><th>Source / accounting basis</th><th>State</th><th>Received</th><th>Record fulfilled</th></tr></thead><tbody>${rows}</tbody></table>${orders.items.length ? '' : '<div class="mon-source-empty"><h4>No matching purchase records</h4><p>Clear the provider/state/player filters or widen the dates. Missing transaction feeds are not zero revenue.</p></div>'}</div><div class="console-pager"><span>${orders.items.length} records on this bounded page · ${orders.limit} row limit</span><button class="btn" id="purchase-previous" ${params.get('cursor') ? '' : 'disabled'}>${back.length?'Previous':'First page'}</button><button class="btn" id="purchase-next" data-cursor="${esc(orders.next_cursor || '')}" ${orders.next_cursor ? '' : 'disabled'}>Next</button></div>`;
  const sources=`<div class="commerce-source-grid">${[['Verified player spend','Unavailable','No verified amount / original-currency feed'],['Estimated ad revenue','Unavailable','No paid-impression revenue feed'],['Settlement & refunds','Unavailable','No payout/reconciliation/reversal ledger'],['Purchase record inspection','Available','Bounded server states and separate simulation']].map(([title,value,note])=>monStat(title,value,note,value==='Unavailable'?'unknown':'')).join('')}</div><p class="mon-caption">Purchase fulfillment, gross player spend, estimated ad proceeds and reconciled cash are separate sources. Product test prices and simulated purchases cannot establish any financial total.</p>`;
  return `<div class="mon-view commerce-workspace">${intro('Monetisation','Separate financial coverage from purchase delivery and development catalogue controls.','SUSTAINABLE BUSINESS')}<div class="mon-view-actions">${monLink('players','Investigate a player',params)}${monLink('cases','Open a purchase support case',params)}${monLink('system/audit','Inspect catalogue change audit',params)}</div>${monCard('Financial source coverage','Accounting basis and missing feeds stay explicit',sources)}${monCard('Purchase history','Follow each recorded purchase to its player and access evidence',purchases)}${monCard('Development catalogue controls','Audited availability changes; no financial or recovery authority',controls)}<p class="mon-caption">Initial publishing allowance is one slot, with no monthly refill. Monthly ad-free access uses one UTC calendar month from purchase. Real Play verification, signed production ad fulfillment, revenue, refunds and a complete reversal ledger remain unavailable in this console.</p></div>`;
}
function wireCommerce(params) {
  const filter = $('#purchase-filters');
  if (filter) filter.onsubmit = event => {
    event.preventDefault();
    const query = new URLSearchParams(params); query.delete('cursor');
    for (const [name, value] of new FormData(filter)) if (value) query.set(name, value); else query.delete(name);
    location.hash = 'economy?' + query;
  };
  if ($('#purchase-next')) $('#purchase-next').onclick = () => {if(!commerceCurrent||commerceCurrent.auth!==authGeneration)return;const back=commerceBack.get(commerceCurrent.scope)||[];back.push(params.get('cursor')||'');if(back.length>100)back.shift();commerceBack.set(commerceCurrent.scope,back);if(commerceBack.size>16)commerceBack.delete(commerceBack.keys().next().value);params.set('cursor', $('#purchase-next').dataset.cursor); location.hash = 'economy?' + params; };
  if ($('#purchase-previous')) $('#purchase-previous').onclick = () => {if(!commerceCurrent||commerceCurrent.auth!==authGeneration)return;const back=commerceBack.get(commerceCurrent.scope)||[],cursor=back.pop();cursor?params.set('cursor',cursor):params.delete('cursor');location.hash='economy?'+params;};
  document.querySelectorAll('[data-product]').forEach(button => button.onclick = () => productCommand(button.dataset));
}
function productCommand(data) {
  const current = data.enabled === 'true';
  const body = {command_id: crypto.randomUUID(), expected_revision: Number(data.revision), enabled: !current, acknowledged: true};
  modal(`<h2>${current ? 'Disable' : 'Enable'} product</h2>${kv({product_id:data.product, before:current, after:!current, expected_revision:body.expected_revision})}<p>Changes apply to new checkout only. Purchased access and accepted pending transactions remain valid.</p><form id="product-command"><label>Recorded reason<textarea id="product-reason" minlength="8" maxlength="500" required></textarea></label><label><input type="checkbox" required> I understand this changes the testing catalog.</label><p id="product-error" class="console-error" hidden></p><div class="console-actions"><button type="button" class="btn" data-close>Cancel</button><button id="product-submit" class="btn btn-primary">Confirm change</button></div></form>`);
  const token=dialogToken();
  $('#product-command').onsubmit = async event => {
    event.preventDefault();
    body.reason = $('#product-reason').value;
    $('#product-submit').disabled = true;
    try { await api('products/' + encodeURIComponent(data.product), body); if(!dialogIsCurrent(token))return; $('#dialog').close(); await render(); }
    catch (error) { if(!dialogIsCurrent(token))return; $('#product-error').hidden = false; $('#product-error').textContent = error.message; $('#product-submit').disabled = false; }
  };
}
