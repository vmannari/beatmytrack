'use strict';
function playerCommerce(id, entitlements) {
  return card('Purchases & access', `<p><a class="btn" href="#economy?player_id=${encodeURIComponent(id)}">Inspect this player's purchases</a></p>${entitlements ? kv(entitlements) : ''}<p class="console-note">Simulated balances are separate from verified store entitlements. Availability changes never revoke owned access.</p>`);
}
async function commercePage(params) {
  const query = new URLSearchParams();
  for (const field of ['player_id', 'state', 'provider', 'cursor']) if (params.get(field)) query.set(field, params.get(field));
  const [catalog, orders] = await Promise.all([api('products'), api('purchases?' + query)]);
  const option = (name, value, label) => `<option value="${value}" ${params.get(name) === value ? 'selected' : ''}>${label}</option>`;
  const controls = `<div class="console-table"><table><thead><tr><th>Product</th><th>Test EUR price</th><th>Availability</th><th>Revision</th><th>Action</th></tr></thead><tbody>${catalog.items.map(p => `<tr><td>${esc(p.title)}</td><td>€${esc(p.price_eur)}</td><td>${status(p.enabled ? 'enabled' : 'disabled')}</td><td>${p.revision}</td><td>${catalog.editable ? `<button class="btn" data-product="${esc(p.id)}" data-enabled="${p.enabled}" data-revision="${p.revision}">${p.enabled ? 'Disable' : 'Enable'}</button>` : 'Read only'}</td></tr>`).join('')}</tbody></table></div><p class="console-note">Owner-only testing controls. Disabling blocks new checkout; accepted pending purchases and existing entitlements remain valid. Real store billing is not connected.</p>`;
  const rows = orders.items.map(p => `<tr><td>${esc(p.product_id)}${p.test_adjustment ? '<br><small>Test adjustment</small>' : ''}</td><td>${link('players', p.player_id)}</td><td>${esc(p.simulated ? 'Simulation · no payment' : p.provider)}</td><td>${status(p.state)}</td><td>${esc(date(p.created_at))}</td><td>${esc(date(p.fulfilled_at))}</td><td><small>${esc(p.id)}</small></td></tr>`).join('');
  const purchases = `<form id="purchase-filters" class="console-toolbar"><label>Player ID<input name="player_id" value="${esc(params.get('player_id') || '')}" placeholder="Exact player UUID"></label><label>State<select name="state">${option('state', '', 'All states')}${['approved','pending','declined','cancelled'].map(s => option('state', s, s)).join('')}</select></label><label>Provider<select name="provider">${option('provider', '', 'All providers')}${option('provider', 'simulation', 'Simulation')}${option('provider', 'google_play', 'Google Play')}</select></label><button class="btn">Apply filters</button></form><div class="console-table"><table><thead><tr><th>Product</th><th>Player</th><th>Provider</th><th>State</th><th>Created</th><th>Fulfilled</th><th>Record ID</th></tr></thead><tbody>${rows}</tbody></table>${orders.items.length ? '' : '<p class="console-empty">No matching purchase records.</p>'}</div><div class="console-pager"><span>${orders.items.length} records on this page · no revenue inferred from simulated purchases</span><button class="btn" id="purchase-previous" ${params.get('cursor') ? '' : 'disabled'}>Previous</button><button class="btn" id="purchase-next" data-cursor="${esc(orders.next_cursor || '')}" ${orders.next_cursor ? '' : 'disabled'}>Next</button></div>`;
  return intro('Purchases & catalog', 'Inspect each player’s delivery records and control items offered during testing.', 'GROW') + card('Purchasable items', controls) + card('Purchase history', purchases);
}
function wireCommerce(params) {
  const filter = $('#purchase-filters');
  if (filter) filter.onsubmit = event => {
    event.preventDefault();
    const query = new URLSearchParams();
    for (const [name, value] of new FormData(filter)) if (value) query.set(name, value);
    location.hash = 'economy?' + query;
  };
  if ($('#purchase-next')) $('#purchase-next').onclick = () => { params.set('cursor', $('#purchase-next').dataset.cursor); location.hash = 'economy?' + params; };
  if ($('#purchase-previous')) $('#purchase-previous').onclick = () => history.back();
  document.querySelectorAll('[data-product]').forEach(button => button.onclick = () => productCommand(button.dataset));
}
function productCommand(data) {
  const current = data.enabled === 'true';
  const body = {command_id: crypto.randomUUID(), expected_revision: Number(data.revision), enabled: !current, acknowledged: true};
  modal(`<h2>${current ? 'Disable' : 'Enable'} product</h2>${kv({product_id:data.product, before:current, after:!current, expected_revision:body.expected_revision})}<p>Changes apply to new checkout only. Purchased access and accepted pending transactions remain valid.</p><form id="product-command"><label>Recorded reason<textarea id="product-reason" minlength="8" maxlength="500" required></textarea></label><label><input type="checkbox" required> I understand this changes the testing catalog.</label><p id="product-error" class="console-error" hidden></p><div class="console-actions"><button type="button" class="btn" data-close>Cancel</button><button id="product-submit" class="btn btn-primary">Confirm change</button></div></form>`);
  $('#product-command').onsubmit = async event => {
    event.preventDefault();
    body.reason = $('#product-reason').value;
    $('#product-submit').disabled = true;
    try { await api('products/' + encodeURIComponent(data.product), body); $('#dialog').close(); await render(); }
    catch (error) { $('#product-error').hidden = false; $('#product-error').textContent = error.message; $('#product-submit').disabled = false; }
  };
}
