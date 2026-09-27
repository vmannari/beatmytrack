'use strict';
const $ = id => document.getElementById(id);
const names = ['Focus', 'Momentum', 'Drive', 'Flow', 'Lift', 'Breakthrough'];
let context, master, analyser, catalog = [], tracks = [], playing = false;
let position = 0, startTime = 0, lastTime = 0, streak = 0, recovery = 0;
let nextId = 1, loading = false;
const buffers = new Map();
const meterData = new Float32Array(2048);
const numeric = (id, fallback) => Number.isFinite($(id).valueAsNumber) ? $(id).valueAsNumber : fallback;
const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));
function status(text, error = false) { $('status').textContent = text; $('status').classList.toggle('error', error); }
function guard(action) { return async (...args) => { try { await action(...args); } catch (error) { status(error.message, true); } }; }
function ensureAudio() {
  if (!context) {
    context = new AudioContext(); master = context.createGain();
    analyser = context.createAnalyser(); analyser.fftSize = 2048;
    master.connect(analyser); analyser.connect(context.destination);
    master.gain.value = numeric('master', .5);
  }
  return context;
}
function playhead() { return playing ? position + Math.max(0, context.currentTime - startTime) : position; }
function stageAt(seconds) {
  if (recovery > 0) return 0;
  const fraction = clamp((seconds - numeric('qualify', 4)) / numeric('build', 24), 0, 1);
  return fraction === 1 ? 5 : Math.min(4, Math.floor(fraction * 5));
}
function targets() {
  const stage = stageAt(streak), mode = $('mode').value;
  const candidates = tracks.filter(t => t.enabled), solo = candidates.some(t => t.solo);
  const eligible = candidates.filter(t => !solo || t.solo);
  let chosen;
  if (mode === 'arrangement') {
    const below = eligible.filter(t => t.stage <= stage);
    chosen = (below.length ? below : eligible).reduce((best, t) => {
      if (!best) return t;
      return below.length ? (t.stage > best.stage ? t : best) : (t.stage < best.stage ? t : best);
    }, null);
  }
  return tracks.map(t => {
    const audible = eligible.includes(t) && (mode === 'manual' || (mode === 'layers' && t.stage <= stage) || (mode === 'arrangement' && t === chosen));
    return audible ? t.volume : 0;
  });
}
function applyMix(immediate = false) {
  const values = targets();
  tracks.forEach((t, i) => {
    const value = values[i];
    if (t.gain && (immediate || t.target !== value)) {
      const parameter = t.gain.gain, now = context.currentTime;
      parameter.cancelAndHoldAtTime(now);
      if (immediate) parameter.setValueAtTime(0, startTime);
      parameter.linearRampToValueAtTime(value, (immediate ? startTime : now) + (immediate ? .02 : numeric('fade', .65)));
    }
    t.target = value;
    const row = document.querySelector(`[data-track="${t.id}"]`);
    if (row) { row.classList.toggle('playing', value > 0); row.querySelector('.audible').textContent = value > 0 ? 'In mix' : 'Silent'; }
  });
}
function stopSources() {
  tracks.forEach(t => { if (t.source) { t.source.stop(); t.source.disconnect(); t.gain.disconnect(); t.source = null; t.gain = null; } });
}
function startSources() {
  const when = context.currentTime + .04;
  startTime = when; lastTime = when;
  for (const t of tracks) {
    const source = context.createBufferSource(), gain = context.createGain();
    source.buffer = t.buffer; source.loop = true;
    source.loopStart = t.trimStart; source.loopEnd = t.trimEnd;
    const length = t.trimEnd - t.trimStart;
    source.connect(gain); gain.connect(master); gain.gain.value = 0;
    source.start(when, t.trimStart + position % length);
    t.source = source; t.gain = gain;
  }
  applyMix(true);
}
function renderTime() {
  const p = playhead();
  $('position').textContent = `${Math.floor(p / 60)}:${(p % 60).toFixed(1).padStart(4, '0')}`;
  $('streak').max = Math.max(60, numeric('build', 24) + numeric('qualify', 4) + 10, streak);
  $('streak').value = streak;
  $('streakValue').innerHTML = `${streak.toFixed(1)}<span>s</span>`;
  $('recovery').textContent = recovery > 0 ? `Collision recovery · ${recovery.toFixed(1)} s` : (stageAt(streak) === 5 ? 'Full clean-streak payoff' : 'Building from qualifying driving');
  $('seek').max = Math.max(120, p + 1); $('seek').value = p; $('seekValue').textContent = p.toFixed(1) + ' s';
  const stage = stageAt(streak); $('stage').textContent = names[stage];
  [...$('stages').children].forEach((b, i) => { b.classList.toggle('active', i === stage); b.setAttribute('aria-pressed', String(i === stage)); });
}
function tick() {
  if (playing) {
    const now = context.currentTime, dt = Math.max(0, now - lastTime); lastTime = Math.max(lastTime, now);
    if ($('advance').checked) {
      const held = Math.min(recovery, dt); recovery -= held; streak += dt - held;
      streak = Math.min(streak, numeric('qualify', 4) + numeric('build', 24));
    }
    applyMix();
  }
  if (analyser) {
    analyser.getFloatTimeDomainData(meterData);
    let peak = 0; for (const value of meterData) peak = Math.max(peak, Math.abs(value));
    $('meter').textContent = `Output peak ${peak > 0 ? (20 * Math.log10(peak)).toFixed(1) + ' dBFS' : '—'}${peak >= .99 ? ' · REDUCE GAIN' : ''}`;
  }
  renderTime();
}
function restartSources() { if (playing) { position = playhead(); stopSources(); startSources(); } }
function field(tag, options = {}) { const node = document.createElement(tag); Object.assign(node, options); return node; }
function renderTracks() {
  $('tracks').replaceChildren(); $('count').textContent = tracks.length; $('empty').hidden = tracks.length > 0;
  for (const t of tracks) {
    const row = field('div', {className: 'track'}); row.dataset.track = t.id;
    const title = field('div', {className: 'track-title'});
    title.append(field('strong', {textContent: t.name}), field('small', {textContent: `${t.kind} · ${t.buffer.duration.toFixed(1)} s · ${t.alignment}`}));
    const toggles = field('div', {className: 'toggles'});
    for (const [key, label] of [['enabled', 'On'], ['solo', 'Solo']]) {
      const l = field('label'), input = field('input', {type: 'checkbox', checked: t[key]});
      input.setAttribute('aria-label', `${label} ${t.name}`);
      input.onchange = () => { t[key] = input.checked; applyMix(); };
      l.append(input, document.createTextNode(label)); toggles.append(l);
    }
    title.append(toggles);
    const stageLabel = field('label', {textContent: 'Entry stage'}), select = field('select');
    names.forEach((name, i) => select.append(field('option', {textContent: name, value: i})));
    select.value = t.stage; select.onchange = () => { t.stage = Number(select.value); applyMix(); }; stageLabel.append(select);
    const volumeLabel = field('label', {textContent: 'Level'}), volume = field('input', {type: 'range', min: 0, max: 1, step: .01, value: t.volume}), volumeValue = field('output', {textContent: Math.round(t.volume * 100) + '%'});
    volume.oninput = () => { t.volume = Number(volume.value); volumeValue.textContent = Math.round(t.volume * 100) + '%'; applyMix(); }; volumeLabel.append(volume, volumeValue);
    row.append(title, stageLabel, volumeLabel);
    for (const [key, label] of [['trimStart', 'Loop in, s'], ['trimEnd', 'Loop out, s']]) {
      const l = field('label', {textContent: label}), input = field('input', {type: 'number', min: 0, max: t.buffer.duration, step: .01, value: t[key].toFixed(2)});
      input.onchange = () => {
        const value = Number(input.value);
        if (!Number.isFinite(value) || value < 0 || value > t.buffer.duration || (key === 'trimStart' ? value >= t.trimEnd - .02 : value <= t.trimStart + .02)) { input.value = t[key]; status('Loop out must follow loop in by at least 0.02 s.', true); return; }
        t[key] = value; restartSources();
      };
      l.append(input); row.append(l);
    }
    const audible = field('output', {className: 'audible'}), remove = field('button', {textContent: '×', title: 'Remove recording'});
    remove.setAttribute('aria-label', `Remove ${t.name}`);
    remove.onclick = () => { position = playhead(); stopSources(); tracks = tracks.filter(x => x !== t); if (playing) startSources(); renderTracks(); };
    row.append(audible, remove); $('tracks').append(row);
  }
  applyMix();
}
async function addRecording(item, file, settings = {}) {
  if (tracks.length >= 12) throw new Error('Maximum 12 audition tracks; remove one first.');
  const ctx = ensureAudio();
  let buffer = buffers.get(item.id);
  if (!buffer) {
    status('Loading ' + item.name + '…');
    if (file && file.size > 100 * 1024 * 1024) throw new Error('Import files under 100 MB.');
    const response = file ? null : await fetch(item.url, {signal: AbortSignal.timeout(60000)});
    if (response && !response.ok) throw new Error('Recording unavailable: ' + item.name);
    const bytes = await (file ? file.arrayBuffer() : response.arrayBuffer());
    status('Decoding ' + item.name + '…');
    buffer = await ctx.decodeAudioData(bytes);
    buffers.set(item.id, buffer);
  }
  if (buffer.duration < .04) throw new Error('Recording is too short.');
  position = playhead(); stopSources();
  const t = {id: nextId++, asset: item.id, name: item.name, kind: item.kind || 'imported audio', alignment: item.alignment || 'unverified',
    buffer, stage: item.state_index ?? 0, volume: .65, enabled: true, solo: false, trimStart: 0, trimEnd: buffer.duration, ...settings};
  tracks.push(t); if (playing) startSources(); renderTracks(); status('Added ' + item.name);
}
async function refresh() {
  const response = await fetch('/api/catalog'); if (!response.ok) throw new Error('Cannot load audio catalog');
  const result = await response.json(); catalog = result.items;
  const selection = $('recording').value;
  $('recording').replaceChildren(field('option', {value: '', textContent: 'Select a recording…'}));
  for (const item of catalog) $('recording').append(field('option', {value: item.id, textContent: `${item.name} · v${item.variant} · ${item.metrics?.duration?.toFixed(1) ?? '?'} s · ${item.run}`}));
  $('recording').value = catalog.some(x => x.id === selection) ? selection : catalog.at(-1)?.id || '';
  recordingInfo(); status(`${catalog.length} recordings available.${result.errors.length ? ' Some manifests could not be read.' : ''}`);
}
function recordingInfo() {
  const item = catalog.find(x => x.id === $('recording').value);
  $('recordingInfo').textContent = item ? `${item.family} · ${item.kind} · ${item.alignment}. ${item.metrics?.near_full_scale_samples || item.source_near_full_scale_samples ? 'Source contains near-full-scale samples; inspect for clipping. ' : ''}${item.prompt}` : 'Generate a concept or import your own audio to begin.';
}
function saveSetup() {
  const data = {schema: 'bmt-audition-1', mode: $('mode').value, streak, position: playhead(),
    settings: Object.fromEntries(['build', 'qualify', 'hold', 'fade', 'master'].map(id => [id, numeric(id, 0)])),
    tracks: tracks.map(({asset, stage, volume, enabled, solo, trimStart, trimEnd}) => ({asset, stage, volume, enabled, solo, trimStart, trimEnd}))};
  const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], {type: 'application/json'}));
  const link = field('a', {href: url, download: 'music-audition.json'}); link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  status('Setup saved. Imported audio must be reselected after a page reload.');
}
async function loadSetup(file) {
  if (!file) return;
  const data = JSON.parse(await file.text());
  if (data.schema !== 'bmt-audition-1' || !Array.isArray(data.tracks) || data.tracks.length > 12 || !['arrangement', 'layers', 'manual'].includes(data.mode)) throw new Error('Unsupported audition setup');
  const missing = data.tracks.filter(t => !catalog.some(i => i.id === t.asset) && !buffers.has(t.asset));
  if (missing.length) throw new Error('Reselect missing imported audio before loading: ' + missing.map(t => t.asset).join(', '));
  for (const t of data.tracks) {
    if (!Number.isInteger(t.stage) || t.stage < 0 || t.stage > 5 || !Number.isFinite(t.volume) || t.volume < 0 || t.volume > 1 || !Number.isFinite(t.trimStart) || !Number.isFinite(t.trimEnd) || t.trimStart < 0 || t.trimEnd - t.trimStart < .02) throw new Error('Invalid track settings');
  }
  for (const id of ['build', 'qualify', 'hold', 'fade', 'master']) {
    const value = data.settings?.[id]; if (!Number.isFinite(value) || value < Number($(id).min) || value > Number($(id).max)) throw new Error('Invalid setting: ' + id);
  }
  if (![data.streak, data.position].every(x => Number.isFinite(x) && x >= 0 && x <= 86400)) throw new Error('Invalid timeline');
  stopSources(); playing = false; $('play').textContent = 'Play'; tracks = [];
  for (const id of ['build', 'qualify', 'hold', 'fade', 'master']) $(id).value = data.settings[id];
  $('master').dispatchEvent(new Event('input')); $('mode').value = data.mode; updateMode();
  streak = data.streak; position = data.position; recovery = 0;
  for (const t of data.tracks) {
    const item = catalog.find(i => i.id === t.asset) || {id: t.asset, name: t.asset.replace('local:', ''), kind: 'imported audio'};
    const settings = {...t}; delete settings.asset;
    await addRecording(item, null, settings);
    const last = tracks.at(-1);
    if (last.trimEnd > last.buffer.duration + .001) { tracks.pop(); renderTracks(); throw new Error('Loop range exceeds recording duration'); }
  }
  renderTime(); status('Setup loaded. Press Play to audition.');
}
function updateMode() {
  $('modeHelp').textContent = {arrangement: 'Assign one arrangement to each stage. Missing stages hold the nearest lower available stage. The first added take wins ties.', layers: 'Selected layers enter cumulatively at their assigned stage. Use aligned stems for musical synchronization.', manual: 'All enabled tracks play together. Solo isolates selected tracks. Clean streak is a reference only in this mode.'}[$('mode').value];
  applyMix();
}
names.forEach((name, i) => { const button = field('button', {textContent: name}); button.onclick = () => { recovery = 0; streak = i ? numeric('qualify', 4) + numeric('build', 24) * i / 5 + .000001 : 0; applyMix(); renderTime(); }; $('stages').append(button); });
$('play').onclick = guard(async () => {
  if (playing) { position = playhead(); stopSources(); playing = false; $('play').textContent = 'Play'; return; }
  if (!tracks.length) throw new Error('Add a recording first.');
  await ensureAudio().resume(); playing = true; startSources(); $('play').textContent = 'Pause'; status('Playing locally.');
});
$('restart').onclick = () => { stopSources(); position = 0; streak = 0; recovery = 0; if (playing) startSources(); applyMix(); renderTime(); };
$('collision').onclick = () => { streak = 0; recovery = numeric('hold', 5); applyMix(); renderTime(); };
$('streak').oninput = () => { streak = Number($('streak').value); recovery = 0; applyMix(); renderTime(); };
$('seek').oninput = () => { stopSources(); position = Number($('seek').value); if (playing) startSources(); renderTime(); };
$('master').oninput = () => { if (master) master.gain.setTargetAtTime(numeric('master', .5), context.currentTime, .03); $('masterValue').textContent = Math.round(numeric('master', .5) * 100) + '%'; };
for (const id of ['build', 'qualify', 'hold', 'fade']) $(id).onchange = () => { $(id).value = clamp(numeric(id, Number($(id).min)), Number($(id).min), Number($(id).max)); applyMix(); renderTime(); };
$('mode').onchange = updateMode; $('refresh').onclick = guard(refresh); $('recording').onchange = recordingInfo;
$('pair').onclick = guard(async () => {
  if (loading) return;
  await refresh();
  const pair = [0, 5].map(stage => {
    const options = catalog.filter(i => i.state_index === stage);
    return options.filter(i => i.name.endsWith('_prepared')).at(-1) || options.at(-1);
  });
  if (pair.some(i => !i)) throw new Error('Generate Focus and Breakthrough first, then refresh.');
  loading = true; $('pair').disabled = true;
  try {
    $('clear').click(); streak = 0; recovery = 0; $('mode').value = 'arrangement'; updateMode();
    for (const item of pair) await addRecording(item);
    status('Endpoint pair loaded. Press Play; jump between Focus and Breakthrough to compare.');
  } finally { loading = false; $('pair').disabled = false; }
});
const audition = field('button', {id:'audition', className:'wide', textContent:'Audition selected recording'});
$('add').before(audition);
audition.onclick = guard(async () => {
  if (loading) return;
  const item = catalog.find(x => x.id === $('recording').value);
  if (!item) throw new Error('Select a recording first.');
  loading = true; audition.disabled = true;
  try {
    await ensureAudio().resume(); $('clear').click();
    $('mode').value = 'manual'; updateMode();
    await addRecording(item);
    playing = true; startSources(); $('play').textContent = 'Pause';
  } finally { loading = false; audition.disabled = false; }
});
$('add').onclick = guard(async () => {
  if (loading) return; const item = catalog.find(x => x.id === $('recording').value); if (!item) throw new Error('Select a recording first.');
  loading = true; $('add').disabled = true;
  try { await addRecording(item); } finally { loading = false; $('add').disabled = false; }
});
$('files').onchange = guard(async event => { for (const file of event.target.files) await addRecording({id: `local:${file.name}:${file.size}:${file.lastModified}`, name: file.name}, file); event.target.value = ''; });
$('clear').onclick = () => { stopSources(); tracks = []; playing = false; position = 0; $('play').textContent = 'Play'; renderTracks(); };
$('save').onclick = saveSetup; $('load').onchange = guard(async event => { await loadSetup(event.target.files[0]); event.target.value = ''; });
setInterval(tick, 50);
guard(refresh)();
// Exposed for the standalone browser regression harness, never used by the game.
window.workbench = {stageAt, targets, getState: () => ({playing, streak, recovery, position: playhead(), tracks: tracks.map(t => ({asset:t.asset, stage:t.stage, target:t.target, volume:t.volume, enabled:t.enabled, solo:t.solo})), sampleRate: context?.sampleRate})};
