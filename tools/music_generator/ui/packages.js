'use strict';
const el = id => document.getElementById(id);
const make = (tag, text, cls) => { const n = document.createElement(tag); if (text !== undefined) n.textContent = text; if (cls) n.className = cls; return n; };
let library = {tracks: [], packages: [], states: []}, draft = null, activeState = 0, dirty = false;
const copy = value => JSON.parse(JSON.stringify(value));
const trackName = t => t.title || t.name || 'Untitled track';
function changed() { dirty = true; el('packageStatus').textContent = 'UNSAVED CHANGES'; el('previewPackage').hidden = true; renderIssues(); }
function canLeave() { return !dirty || window.confirm('Discard your unsaved soundtrack edits?'); }
function renderList() {
  el('packageCount').textContent = library.packages.length; el('noPackages').hidden = library.packages.length > 0;
  el('packageList').replaceChildren(...library.packages.map(p => {
    const b = make('button', undefined, 'recording-row' + (draft?.id === p.id ? ' selected' : '')); b.type = 'button'; b.dataset.package = p.id;
    const text = make('span', undefined, 'recording-text'); text.append(make('strong', p.name), make('small', `${p.states.length} states · ${p.mode === 'layers' ? 'Layer stack' : 'Switch tracks'} · ${p.ready ? 'Ready to audition' : 'Draft'}`));
    b.append(text); b.onclick = () => { if (canLeave()) openPackage(p); }; return b;
  }));
}
function openPackage(value) {
  draft = copy(value); activeState = 0; dirty = false;
  el('packageEmpty').hidden = true; el('packageEditor').hidden = false;
  el('packageName').value = draft.name; el('packageStateCount').value = draft.states.length;
  document.querySelector(`input[name=packageMode][value=${draft.mode}]`).checked = true;
  el('duplicatePackage').hidden = el('deletePackage').hidden = !draft.id;
  el('packageStatus').textContent = draft.id ? (draft.ready ? 'READY TO AUDITION' : 'DRAFT') : 'NEW PACKAGE';
  el('previewPackage').hidden = !draft.id || !draft.ready; el('previewPackage').href = `/lab.html?package=${draft.id || ''}`;
  renderList(); renderStates(); renderPool(); renderIssues();
}
function renderStates() {
  el('packageStates').replaceChildren(...draft.states.map((stage, i) => {
    const button = make('button', undefined, 'pool-state' + (i === activeState ? ' active' : '')); button.type = 'button'; button.dataset.index = i; button.setAttribute('aria-pressed', String(i === activeState));
    button.append(make('span', String(i + 1).padStart(2, '0'), 'state-number'), make('span', stage.name || 'Unnamed state'), make('b', String(stage.pool.length)));
    button.onclick = () => { activeState = i; el('poolSearch').value = ''; renderStates(); renderPool(); }; return button;
  }));
}
function renderPool() {
  const stage = draft.states[activeState]; el('poolName').value = stage.name;
  el('poolCount').textContent = `${stage.pool.length} selected · one plays in this state${draft.mode === 'layers' ? ', alongside the earlier layers' : ''}`;
  const search = el('poolSearch').value.toLowerCase();
  const visible = library.tracks.filter(t => trackName(t).toLowerCase().includes(search));
  el('poolTracks').replaceChildren(...visible.map(track => {
    const label = make('label', undefined, 'pool-track');
    const check = make('input'); check.type = 'checkbox'; check.value = track.id; check.checked = stage.pool.includes(track.id); check.disabled = !!track.missing && !check.checked;
    const text = make('span'); text.append(make('strong', trackName(track)), make('small', track.missing ? 'Source file missing' : `${(track.metrics?.duration || 0).toFixed(1)} sec · ${library.states[track.state_index] || 'Unassigned'}`));
    check.onchange = () => { stage.pool = check.checked ? [...stage.pool, track.id] : stage.pool.filter(a => a !== track.id); changed(); renderStates(); el('poolCount').textContent = `${stage.pool.length} selected · one chosen per drive`; };
    label.append(check, text); return label;
  }));
  if (!visible.length) el('poolTracks').append(make('p', library.tracks.length ? 'No matching saved tracks.' : 'Save a recording to your library to start filling this pool.', 'field-hint'));
}
function renderIssues() {
  if (!draft) return;
  const available = new Set(library.tracks.filter(t => !t.missing).map(t => t.id));
  const problems = draft.states.flatMap(s => !s.pool.length ? [`${s.name || 'Unnamed state'} needs a track.`] : s.pool.some(a => !available.has(a)) ? [`${s.name} contains an unavailable track.`] : []);
  el('packageIssues').textContent = problems.length ? `Save as a draft, or finish the pools to audition: ${problems.join(' ')}` : 'All pools have recordings. A new drive will draw one from each pool and keep that selection as states change.';
}
el('newPackage').onclick = () => {
  if (!canLeave()) return;
  openPackage({name: '', mode: 'layers', states: library.states.map(name => ({name, pool: []}))});
  el('packageName').focus();
};
el('packageName').oninput = () => { draft.name = el('packageName').value; changed(); };
document.querySelectorAll('[name=packageMode]').forEach(input => input.onchange = () => { draft.mode = input.value; changed(); renderPool(); });
el('packageStateCount').onchange = () => {
  if (!el('packageStateCount').reportValidity()) return;
  const count = Number(el('packageStateCount').value);
  if (count === draft.states.length) return;
  draft.states = Array.from({length: count}, (_, i) => draft.states[i] || {name: `State ${i + 1}`, pool: []});
  activeState = Math.min(activeState, count - 1); changed(); renderStates(); renderPool();
};
el('poolName').oninput = () => { draft.states[activeState].name = el('poolName').value; changed(); renderStates(); };
el('poolSearch').oninput = renderPool;
el('packageForm').onsubmit = async event => {
  event.preventDefault(); el('savePackage').disabled = true;
  try {
    const saved = await StudioUI.api('/api/packages/save', {id: draft.id, name: draft.name, mode: draft.mode, states: draft.states});
    library = await StudioUI.getSnapshot(); StudioUI.update(library); openPackage(library.packages.find(p => p.id === saved.id)); StudioUI.notice('Soundtrack saved.');
  } catch (e) { StudioUI.notice(e.message, true); } finally { el('savePackage').disabled = false; }
};
el('duplicatePackage').onclick = () => { const cloned = copy(draft); delete cloned.id; cloned.name += ' · copy'; openPackage(cloned); changed(); };
el('deletePackage').onclick = () => el('packageDeleteDialog').showModal();
el('cancelPackageDelete').onclick = () => el('packageDeleteDialog').close();
el('confirmPackageDelete').onclick = async () => {
  try { await StudioUI.api('/api/packages/delete', {id: draft.id}); dirty = false; draft = null; el('packageDeleteDialog').close(); library = await StudioUI.getSnapshot(); renderList(); el('packageEditor').hidden = true; el('packageEmpty').hidden = false; StudioUI.notice('Soundtrack deleted. Your recordings are still in the library.'); }
  catch (e) { StudioUI.notice(e.message, true); }
};
window.addEventListener('beforeunload', event => { if (dirty) { event.preventDefault(); event.returnValue = ''; } });
StudioUI.getSnapshot().then(data => { library = data; StudioUI.update(data); renderList(); const id = new URLSearchParams(location.search).get('package'); const item = data.packages.find(p => p.id === id); if (item) openPackage(item); }).catch(e => StudioUI.notice(e.message, true));
