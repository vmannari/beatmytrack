'use strict';
const $ = id => document.getElementById(id);
let states = ['Focus', 'Momentum', 'Drive', 'Flow', 'Lift', 'Breakthrough'];
const active = ['queued', 'loading_model', 'generating'];
let data = {jobs: [], tracks: []}, archive = [], token = '', view = 'create', source = 'saved';
let selected = null, detailKey = '', showDiscarded = false, busy = false, connected = false;
let waveform = [], waveController, decodeContext, toastTimer, snapshotKey = '';
let refreshEpoch = 0;
$('generate').disabled = true;
const audio = $('audio'); audio.volume = .5;
const nameOf = item => item.title || item.name?.replaceAll('_', ' ') || 'Untitled take';
const stateOf = value => states[value] || 'Unassigned';
const time = value => `${Math.floor((value || 0) / 60)}:${String(Math.floor((value || 0) % 60)).padStart(2, '0')}`;
const node = (tag, text, cls) => { const n = document.createElement(tag); if (text !== undefined) n.textContent = text; if (cls) n.className = cls; return n; };
function options(id, filter = false) {
  const old = $(id).options.length ? $(id).value : filter ? 'all' : '';
  $(id).replaceChildren();
  if (filter) $(id).append(new Option('All musical states', 'all'));
  $(id).append(new Option('Unassigned', ''));
  states.forEach((s, i) => $(id).append(new Option(`${String(i + 1).padStart(2, '0')} · ${s}`, String(i))));
  $(id).value = [...$(id).options].some(o => o.value === old) ? old : filter ? 'all' : '';
}
['targetState', 'saveState'].forEach(id => options(id)); options('stateFilter', true);
function notify(message) { $('toast').textContent = message; $('toast').hidden = false; clearTimeout(toastTimer); toastTimer = setTimeout(() => $('toast').hidden = true, 5000); }
function error(message) { notify(message); }
async function api(path, body) {
  const response = await fetch(path, {method: body ? 'POST' : 'GET', headers: body ? {'Content-Type': 'application/json', 'X-Workbench-Token': token} : {}, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(15000)});
  const result = await response.json(); if (!response.ok) throw new Error(result.error || 'The workbench could not complete this action.'); return result;
}
function guard(fn) { return async (...args) => { try { await fn(...args); } catch (e) { error(e.message); } }; }
function storageWrite() { try { localStorage.setItem('bmt-studio-prompt', JSON.stringify({title: $('trackTitle').value, prompt: $('prompt').value, duration: $('duration').value, state: $('targetState').value})); } catch {} }
try { const saved = JSON.parse(localStorage.getItem('bmt-studio-prompt') || 'null'); if (saved) { $('trackTitle').value = saved.title; $('prompt').value = saved.prompt; $('duration').value = saved.duration; $('targetState').value = saved.state; } } catch {}
function promptCount() { $('promptCount').textContent = `${$('prompt').value.length} / 2000`; storageWrite(); }
['trackTitle', 'prompt', 'duration', 'targetState'].forEach(id => $(id).addEventListener('input', promptCount)); promptCount();
const presets = {
  calm: ['The quiet road', 'Low sustained cello and soft felt piano, slow warm instrumental melody, spacious natural room sound, gentle movement, restrained background music, no vocals or percussion.', 0],
  groove: ['Finding momentum', 'Warm rounded bass, dry restrained drums and clean muted guitar, steady rolling instrumental groove, subtle melodic development, relaxed driving energy, no vocals.', 2],
  lift: ['Over the horizon', 'Uplifting instrumental rock with a warm melodic organ, steady bass and live drums, broad sustained guitar chords, a memorable rising melody, controlled energy, no vocals.', 5]
};
document.querySelectorAll('[data-preset]').forEach(button => button.onclick = () => { const [title, prompt, state] = presets[button.dataset.preset]; $('trackTitle').value = title; $('prompt').value = prompt; $('targetState').value = Math.min(state, states.length - 1); promptCount(); $('prompt').focus(); });
function switchView(next) {
  view = next; $('createPanel').hidden = next !== 'create'; $('libraryPanel').hidden = next !== 'library';
  $('breadcrumb').textContent = next === 'create' ? 'Create' : 'Your library';
  $('pageTitle').textContent = next === 'create' ? 'Start with a sound.' : 'Sounds worth keeping.';
  $('pageSubtitle').textContent = next === 'create' ? 'Describe it. Hear it. Keep what moves you.' : 'Your collection, organized for every part of the drive.';
  document.querySelectorAll('[data-view]').forEach(b => { b.classList.toggle('active', b.dataset.view === next); b.setAttribute('aria-current', b.dataset.view === next ? 'page' : 'false'); });
  location.hash = next === 'library' ? 'library' : 'create'; renderLibrary();
}
document.querySelectorAll('[data-view]').forEach(b => b.onclick = () => switchView(b.dataset.view));
window.addEventListener('hashchange', () => { const next = location.hash === '#library' ? 'library' : 'create'; if (next !== view) switchView(next); });
function selectedValue() {
  if (!selected) return {};
  if (selected.kind === 'job') { const job = data.jobs.find(j => j.id === selected.id); return {job, item: job?.item}; }
  return {item: data.tracks.find(t => t.id === selected.id) || data.trash?.find(t => t.id === selected.id) || archive.find(t => t.id === selected.id)};
}
function select(kind, id) { selected = {kind, id}; detailKey = ''; renderDetail(); renderInbox(); renderLibrary(); }
function recordingRow(item, subtitle, state, onClick, chosen) {
  const button = node('button', undefined, 'recording-row' + (chosen ? ' selected' : '')); button.type = 'button'; button.setAttribute('aria-pressed', String(chosen));
  const icon = node('span', '≋', 'recording-icon'); icon.setAttribute('aria-hidden', 'true');
  const text = node('span', undefined, 'recording-text'); text.append(node('strong', nameOf(item)), node('small', subtitle));
  button.append(icon, text, node('span', state, 'row-state')); button.onclick = onClick; return button;
}
function renderNav() {
  StudioUI.update({...data, states}, i => { source = 'saved'; $('stateFilter').value = i; switchView('library'); });
}
function renderLibrary() {
  $('savedSource').setAttribute('aria-pressed', String(source === 'saved')); $('archiveSource').setAttribute('aria-pressed', String(source === 'archive'));
  $('trashSource').setAttribute('aria-pressed', String(source === 'trash'));
  const search = $('search').value.toLowerCase(), filter = $('stateFilter').value;
  const items = (source === 'saved' ? data.tracks : source === 'trash' ? data.trash || [] : archive.filter(i => !i.id.startsWith('workbench/') && !data.trash?.some(t => t.id === i.id))).filter(i =>
    (filter === 'all' || (i.state_index == null ? '' : String(i.state_index)) === filter) && `${nameOf(i)} ${i.full_prompt || i.prompt || ''}`.toLowerCase().includes(search));
  $('resultsCount').textContent = `${items.length} ${items.length === 1 ? 'recording' : 'recordings'}${source === 'archive' ? ' · Previous experiments, available to save' : ''}`;
  $('libraryList').replaceChildren(...items.map(i => recordingRow(i, `${time(i.metrics?.duration)} · ${i.missing ? 'File missing' : (i.kind === 'layer' ? 'Layer' : 'Full mix')}`, stateOf(i.state_index), () => select('asset', i.id), selected?.id === i.id)));
  if (!items.length) $('libraryList').append(node('p', source === 'saved' && !data.tracks.length ? 'Your collection starts with one good take. Create a track, or browse earlier recordings to save a favorite.' : 'No tracks match. Try another search or state.', 'field-hint'));
}
function renderInbox() {
  const jobs = data.jobs.filter(j => showDiscarded ? j.status === 'discarded' : !['saved', 'discarded', 'deleted'].includes(j.status)).slice().reverse();
  $('inboxCount').textContent = data.jobs.filter(j => !['saved', 'discarded', 'deleted'].includes(j.status)).length;
  $('toggleDiscarded').setAttribute('aria-pressed', String(showDiscarded)); $('inboxEmpty').hidden = jobs.length > 0;
  $('inboxEmpty').textContent = showDiscarded ? 'No discarded takes. Source recordings are retained when you discard.' : 'New takes wait here until you save or discard them.';
  $('inboxList').replaceChildren(...jobs.map(j => recordingRow(j, `${time(j.duration)} · ${stateOf(j.state_index)}`, {ready: 'Ready to review', failed: 'Generation failed', discarded: 'Discarded', queued: 'Queued', loading_model: 'Loading model…', generating: 'Generating…'}[j.status], () => select('job', j.id), selected?.id === j.id)));
}
const failure = node('div'); failure.id = 'failurePanel'; failure.hidden = true; $('generationProgress').after(failure);
function renderDetail() {
  const {job, item} = selectedValue();
  const loading = job && active.includes(job.status), failed = job && (job.status === 'failed' || (job.status === 'discarded' && !item));
  $('emptyAudition').hidden = Boolean(loading || failed || item); $('generationProgress').hidden = !loading; failure.hidden = !failed; $('takeDetail').hidden = !item || loading || failed;
  $('takeBadge').textContent = loading ? 'IN PROGRESS' : failed ? 'NEEDS ATTENTION' : item ? (data.tracks.some(t => t.id === item.id) ? 'IN YOUR LIBRARY' : 'AUDITION') : 'YOUR NEXT TAKE';
  if (loading) {
    $('progressTitle').textContent = job.status === 'generating' ? 'Finding your sound' : 'Warming up the studio';
    $('progressText').textContent = job.status === 'generating' ? `Magenta is generating “${job.title}”.` : 'Loading Magenta RT2 on your local GPU.';
    $('elapsed').textContent = `${time(Date.now() / 1000 - job.created)} elapsed`; return;
  }
  if (failed) {
    const key = job.id + job.status; if (key === detailKey) return; detailKey = key;
    const message = node('p', 'Your prompt is kept. Review the error, then try again.', 'field-hint');
    const details = node('details', undefined, 'prompt-details'); details.append(node('summary', 'Error details'), node('p', job.error || 'Generation did not finish.'));
    const retry = node('button', 'Use this prompt', 'primary'); retry.onclick = () => { $('trackTitle').value = job.title; $('prompt').value = job.prompt; $('duration').value = job.duration; $('targetState').value = job.state_index ?? ''; promptCount(); switchView('create'); $('generate').focus(); };
    const discard = node('button', job.status === 'discarded' ? 'Restore take' : 'Dismiss', 'quiet'); discard.onclick = guard(() => changeDiscard(job));
    failure.replaceChildren(node('h3', 'This take didn’t finish.'), message, details, retry, discard); return;
  }
  if (!item) return;
  const saved = data.tracks.find(t => t.id === item.id), state = saved ? saved.state_index : job ? job.state_index : item.state_index;
  const trashed = data.trash?.some(t => t.id === item.id);
  const key = `${item.id}:${job?.status}:${saved?.saved_at}:${trashed}:${states.join('|')}`; if (key === detailKey) return; detailKey = key;
  const name = saved?.title || job?.title || nameOf(item);
  $('detailTitle').textContent = name; $('detailKicker').textContent = trashed ? 'IN TRASH' : saved ? 'SAVED TRACK' : job?.status === 'discarded' ? 'DISCARDED TAKE' : 'UNSAVED TAKE';
  $('detailMeta').textContent = `${time(item.metrics?.duration)} · ${item.metrics?.sample_rate ? `${item.metrics.sample_rate / 1000} kHz` : 'Local audio'} · ${stateOf(state)}`;
  $('detailPrompt').textContent = item.full_prompt || job?.prompt || item.prompt || 'No text prompt recorded for this source.';
  $('provenance').textContent = `${item.model || 'Existing source'} · ${item.kind || 'arrangement'} · ${item.run || ''}${item.prompt_truncated ? '\nMagenta shortened this prompt to its 127-token limit. Effective prompt: ' + item.prompt : ''}`;
  $('saveTitle').value = name; $('saveState').value = state ?? ''; $('saveTrack').textContent = saved ? 'Save changes' : 'Save to library';
  $('saveTrack').disabled = !!item.missing || job?.status === 'discarded'; $('discard').hidden = !job || !!saved; $('discard').textContent = job?.status === 'discarded' ? 'Restore take' : 'Discard take';
  $('saveTrack').hidden = !!trashed; $('saveForm').querySelector('.save-fields').hidden = !!trashed;
  $('deleteTrack').hidden = !saved; $('restoreTrack').hidden = !trashed;
  if (trashed) $('discard').hidden = true;
  $('download').href = item.url || '#'; $('download').hidden = !!item.missing;
  const warnings = [];
  if (item.missing) warnings.push('The source file is missing. Restore it to the music folder to listen again.');
  if (item.metrics?.near_full_scale_samples > 0) warnings.push('This source has near-full-scale samples. Listen for clipping; reducing volume does not repair it.');
  if (item.prompt_truncated) warnings.push('Magenta shortened your prompt. Open Generation prompt & details to see the text it used.');
  $('audioWarning').hidden = warnings.length === 0; $('audioWarning').textContent = warnings.join('\n');
  $('detailPlay').disabled = !!item.missing;
  if (audio.dataset.asset !== item.id) {
    audio.pause(); audio.dataset.asset = item.id; audio.src = item.url || ''; $('playerPlay').disabled = !!item.missing; $('seek').disabled = !!item.missing; loadWaveform(item);
  }
  $('playerTitle').textContent = name; $('playerState').textContent = stateOf(state); $('waveEnd').textContent = time(item.metrics?.duration);
  renderPlayback();
}
async function loadWaveform(item) {
  waveController?.abort(); waveController = new AbortController(); waveform = []; drawWaveform(); $('waveformStatus').hidden = false; $('waveformStatus').textContent = 'Loading waveform…';
  if (item.missing) { $('waveformStatus').textContent = 'Audio unavailable'; return; }
  const signal = waveController.signal;
  try {
    const response = await fetch(item.url, {signal}); if (!response.ok) throw new Error('Audio unavailable');
    decodeContext ||= new AudioContext(); const buffer = await decodeContext.decodeAudioData(await response.arrayBuffer()); if (signal.aborted) return;
    const samples = buffer.getChannelData(0), bins = 160, size = Math.max(1, Math.floor(samples.length / bins));
    waveform = Array.from({length: bins}, (_, i) => { let peak = 0; for (let s = i * size; s < Math.min(samples.length, (i + 1) * size); s++) peak = Math.max(peak, Math.abs(samples[s])); return peak; });
    $('waveformStatus').hidden = true; drawWaveform();
  } catch (e) { if (!signal.aborted) $('waveformStatus').textContent = 'Waveform unavailable. You can still try playback.'; }
}
function drawWaveform() {
  const canvas = $('waveform'), width = canvas.clientWidth || 500, height = 120, ratio = window.devicePixelRatio || 1;
  canvas.width = width * ratio; canvas.height = height * ratio; const ctx = canvas.getContext('2d'); ctx.scale(ratio, ratio); ctx.clearRect(0, 0, width, height);
  if (!waveform.length) return;
  const maximum = Math.max(.01, ...waveform), progress = Number.isFinite(audio.duration) ? audio.currentTime / audio.duration : 0;
  waveform.forEach((peak, i) => { const h = Math.max(2, peak / maximum * 86); ctx.fillStyle = i / waveform.length <= progress ? '#f0ce72' : '#6f8179'; ctx.fillRect(i * width / waveform.length + 1, (height - h) / 2, Math.max(1, width / waveform.length - 2), h); });
}
new ResizeObserver(drawWaveform).observe($('waveform'));
function renderPlayback() { const playing = !audio.paused; $('playerPlay').textContent = $('detailPlay').textContent = playing ? 'Ⅱ' : '▶'; $('detailPlay').setAttribute('aria-label', playing ? 'Pause selected track' : 'Play selected track'); $('playerPlay').setAttribute('aria-label', playing ? 'Pause' : 'Play'); $('currentTime').textContent = time(audio.currentTime); $('totalTime').textContent = time(Number.isFinite(audio.duration) ? audio.duration : 0); $('seek').max = Number.isFinite(audio.duration) ? audio.duration : 1; $('seek').value = audio.currentTime || 0; drawWaveform(); }
async function togglePlay() { if (!audio.getAttribute('src')) return; if (audio.paused) await audio.play(); else audio.pause(); }
$('detailPlay').onclick = $('playerPlay').onclick = guard(togglePlay);
['timeupdate', 'loadedmetadata', 'play', 'pause', 'ended'].forEach(event => audio.addEventListener(event, renderPlayback));
audio.addEventListener('error', () => { if (audio.getAttribute('src')) error('Could not play this recording. Refresh the library and try again.'); });
$('seek').oninput = () => { if (Number.isFinite(audio.duration)) audio.currentTime = Number($('seek').value); };
$('volume').oninput = () => audio.volume = Number($('volume').value);
$('loop').onclick = () => { audio.loop = !audio.loop; $('loop').setAttribute('aria-pressed', String(audio.loop)); };
document.addEventListener('keydown', guard(async event => { if (event.code === 'Space' && !['INPUT', 'TEXTAREA', 'SELECT', 'BUTTON', 'SUMMARY', 'A'].includes(event.target.tagName)) { event.preventDefault(); await togglePlay(); } }));
async function refresh(loadArchive = false) {
  const epoch = ++refreshEpoch;
  try {
    const result = await api('/api/workbench');
    const recordings = loadArchive ? (await api('/api/catalog')).items : null;
    if (epoch !== refreshEpoch) return;
    token = result.token; data = result; connected = true; $('connectionError').hidden = true;
    if (data.states && JSON.stringify(states) !== JSON.stringify(data.states)) {
      states = data.states; ['targetState', 'saveState'].forEach(id => options(id)); options('stateFilter', true);
    }
    if (recordings) archive = recordings;
    const key = JSON.stringify(data); if (key !== snapshotKey || loadArchive) {
      snapshotKey = key;
      if (!selected) { const latest = data.jobs.filter(j => !['saved', 'discarded', 'deleted'].includes(j.status)).at(-1); if (latest) selected = {kind: 'job', id: latest.id}; }
      renderNav(); renderInbox(); renderLibrary();
    }
    renderDetail();
  } catch (e) { connected = false; $('connectionError').textContent = 'Connection lost. Keep the workbench server running. Reconnecting automatically…'; $('connectionError').hidden = false; }
  $('generate').disabled = busy || !connected || data.jobs.some(j => active.includes(j.status));
  $('generate').textContent = data.jobs.some(j => active.includes(j.status)) ? 'Generating…' : '✦  Generate a take  ↗';
}
$('generateForm').onsubmit = async event => {
  event.preventDefault(); if (busy) return; busy = true; $('generate').disabled = true; $('formError').hidden = true;
  try { const job = await api('/api/generate', {title: $('trackTitle').value, prompt: $('prompt').value, duration: Number($('duration').value), state_index: $('targetState').value === '' ? null : Number($('targetState').value)}); selected = {kind: 'job', id: job.id}; detailKey = ''; showDiscarded = false; await refresh(); $('generationProgress').scrollIntoView({block: 'nearest', behavior: 'smooth'}); }
  catch (e) { $('formError').textContent = e.message; $('formError').hidden = false; }
  finally { busy = false; $('generate').disabled = !connected || data.jobs.some(j => active.includes(j.status)); }
};
$('saveForm').onsubmit = guard(async event => {
  event.preventDefault(); const {item} = selectedValue(); if (!item) return; $('saveTrack').disabled = true;
  try { await api('/api/save', {id: item.id, title: $('saveTitle').value, state_index: $('saveState').value === '' ? null : Number($('saveState').value)}); await refresh(true); notify('Saved to your library.'); }
  finally { $('saveTrack').disabled = false; }
});
async function changeDiscard(job) {
  const restore = job.status === 'discarded'; await api('/api/discard', {id: job.id, restore});
  if (!restore) { audio.pause(); audio.removeAttribute('src'); audio.load(); audio.dataset.asset = ''; $('playerPlay').disabled = true; $('seek').disabled = true; $('playerTitle').textContent = 'Nothing playing yet'; $('playerState').textContent = 'Select a take to listen'; selected = null; detailKey = ''; showDiscarded = false; }
  else showDiscarded = false;
  await refresh(); notify(restore ? 'Take restored to your inbox.' : 'Take discarded. Find it under Discarded if you change your mind.');
}
$('discard').onclick = guard(async () => { const {job} = selectedValue(); if (job) await changeDiscard(job); });
$('toggleDiscarded').onclick = () => { showDiscarded = !showDiscarded; renderInbox(); };
$('savedSource').onclick = () => { source = 'saved'; renderLibrary(); };
$('archiveSource').onclick = () => { source = 'archive'; renderLibrary(); };
$('trashSource').onclick = () => { source = 'trash'; renderLibrary(); };
$('deleteTrack').onclick = () => {
  const {item} = selectedValue(); if (!item) return;
  const packages = (data.packages || []).filter(p => p.states.some(s => s.pool.includes(item.id)));
  const savedName = data.tracks.find(t => t.id === item.id)?.title || nameOf(item);
  $('deleteImpact').textContent = `“${savedName}” will move to Trash and be removed from ${packages.length} soundtrack package${packages.length === 1 ? '' : 's'}. Empty pools will need a replacement track.`;
  $('deleteDialog').showModal();
};
$('cancelDelete').onclick = () => $('deleteDialog').close();
$('confirmDelete').onclick = guard(async () => {
  const {item} = selectedValue(); if (!item) return;
  $('confirmDelete').disabled = true;
  try { await api('/api/tracks/delete', {id: item.id}); audio.pause(); audio.removeAttribute('src'); audio.load(); audio.dataset.asset = ''; $('playerPlay').disabled = true; $('seek').disabled = true; $('playerTitle').textContent = 'Nothing playing yet'; $('playerState').textContent = 'Select a take to listen'; selected = null; detailKey = ''; $('deleteDialog').close(); await refresh(true); notify('Track deleted. Restore it from Trash if needed.'); }
  finally { $('confirmDelete').disabled = false; }
});
$('restoreTrack').onclick = guard(async () => { const {item} = selectedValue(); if (!item) return; await api('/api/tracks/restore', {id: item.id}); source = 'saved'; await refresh(true); notify('Track restored. Add it back to package pools where needed.'); });
$('search').oninput = renderLibrary; $('stateFilter').onchange = renderLibrary;
$('refresh').onclick = guard(() => refresh(true));
switchView(location.hash === '#library' ? 'library' : 'create');
const requestedState = new URLSearchParams(location.search).get('state');
if (requestedState !== null) $('stateFilter').value = requestedState;
refresh(true).then(() => { if (requestedState !== null) { $('stateFilter').value = requestedState; renderLibrary(); } }).then(function poll() { setTimeout(async () => { await refresh(); poll(); }, 2000); });
