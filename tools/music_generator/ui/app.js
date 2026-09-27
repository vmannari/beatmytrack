'use strict';
const $ = id => document.getElementById(id);
const names = ['Focus', 'Momentum', 'Drive', 'Flow', 'Lift', 'Breakthrough'];
let context, master, analyser, catalog = [], tracks = [], playing = false;
let position = 0, startTime = 0, lastTime = 0, streak = 0, recovery = 0;
let nextId = 1, loading = false;
const buffers = new Map();
const tempoBuffers = new Map();
const tempoStages = [90, 102, 114, 126, 138, 150];
let activeBpm = 120;
const tempoKey = (asset, bpm) => `${asset}@${bpm}`;
async function prepareTempos(selection = tracks) {
  if (!selection.length || selection.some(t => t.family !== 'shared_road_r3' || t.trimStart !== 0 || Math.abs(t.trimEnd - 16) > .001)) throw new Error('Load an R3 drive with full loops before using evolving tempo.');
  const available = catalog.filter(i => i.family === 'evolving_r4');
  const run = available.map(i => i.run).sort().at(-1);
  const selected = selection.flatMap(t => tempoStages.map(bpm => {
    const item = available.find(i => i.run === run && i.source_asset === t.asset && i.bpm === bpm);
    if (!item) throw new Error('The matching six-tempo bank is unavailable.');
    return {item, key:tempoKey(t.asset, bpm)};
  }));
  for (const {item, key} of selected) {
    if (tempoBuffers.has(key)) continue;
    status(`Loading evolving score · ${item.bpm} BPM · ${item.name}…`);
    const response = await fetch(item.url, {signal:AbortSignal.timeout(60000)});
    if (!response.ok) throw new Error('Tempo recording unavailable');
    tempoBuffers.set(key, await ensureAudio().decodeAudioData(await response.arrayBuffer()));
  }
  const keep = new Set(selected.map(i => i.key));
  for (const key of tempoBuffers.keys()) if (!keep.has(key)) tempoBuffers.delete(key);
}
function syncTempo() {
  const bpm = $('mode').value === 'tempo' && tracks.length && tracks.every(t => tempoBuffers.has(tempoKey(t.asset, tempoStages[stageAt(streak)]))) ? tempoStages[stageAt(streak)] : 120;
  if (bpm === activeBpm) return;
  position = playhead();
  if (playing) stopSources(true);
  activeBpm = bpm;
  if (playing) startSources(context.currentTime);
}
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
function playhead() { return playing ? position + Math.max(0, context.currentTime - startTime) * activeBpm / 120 : position; }
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
    const audible = eligible.includes(t) && (mode === 'manual' || (['layers', 'tempo'].includes(mode) && t.stage <= stage) || (mode === 'arrangement' && t === chosen));
    return audible ? t.volume : 0;
  });
}
function applyMix(immediate = false) {
  syncTempo();
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
function stopSources(fade = false) {
  tracks.forEach(t => { if (t.source) {
    const source = t.source, gain = t.gain;
    if (fade) {
      gain.gain.cancelAndHoldAtTime(context.currentTime);
      gain.gain.linearRampToValueAtTime(0, context.currentTime + .02);
      source.stop(context.currentTime + .02);
      source.onended = () => { source.disconnect(); gain.disconnect(); };
    } else { source.stop(); source.disconnect(); gain.disconnect(); }
    t.source = null; t.gain = null;
  } });
}
function startSources(when = context.currentTime + .04) {
  startTime = when; lastTime = when;
  for (const t of tracks) {
    const source = context.createBufferSource(), gain = context.createGain();
    const tempoBuffer = $('mode').value === 'tempo' ? tempoBuffers.get(tempoKey(t.asset, activeBpm)) : null;
    source.buffer = tempoBuffer || t.buffer; source.loop = true;
    source.loopStart = tempoBuffer ? 0 : t.trimStart; source.loopEnd = tempoBuffer ? tempoBuffer.duration : t.trimEnd;
    const length = source.loopEnd - source.loopStart;
    source.connect(gain); gain.connect(master); gain.gain.value = 0;
    const offset = source.loopStart + (position * (tempoBuffer ? 120 / activeBpm : 1)) % length;
    source.start(when, offset);
    t.startedAt = when; t.startedOffset = offset;
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
  $('tempoReadout').textContent = $('mode').value === 'tempo' ? `${activeBpm} BPM · score beat ${(p * 2 % 32 + 1).toFixed(1)} / 32` : 'Fixed tempo · R3: 120 BPM';
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
  $('warning').textContent = tracks.length && tracks.every(t => t.family === 'shared_road_r3')
    ? 'R3: isolated instruments share one 120 BPM score and 16-second loop. Earlier instruments keep playing as new ones join. Musical taste and transitions still need your listening review.'
    : 'Generated full arrangements have unverified timing and harmony. Only the R3 instrument bank shares an exact score; arbitrary recordings may not layer together.';
  if ($('mode').value === 'tempo') tempoNotice();
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
    if (t.family === 'shared_road_r3') {
      const choice = field('select'); choice.setAttribute('aria-label', `Variation ${t.name}`);
      const options = catalog.filter(i => i.family === t.family && i.run === t.run && i.state_index === t.role);
      for (const item of options) choice.append(field('option', {value:item.id, textContent:`Variation ${'ABC'[item.variant-1]}`}));
      choice.value = t.asset;
      choice.onchange = guard(async () => {
        if (loading) { choice.value = t.asset; return; }
        loading = true;
        try {
          const item = options.find(i => i.id === choice.value);
          let buffer = buffers.get(item.id);
          if (!buffer) {
            const response = await fetch(item.url, {signal:AbortSignal.timeout(60000)});
            if (!response.ok) throw new Error('Recording unavailable');
            buffer = await ensureAudio().decodeAudioData(await response.arrayBuffer()); buffers.set(item.id, buffer);
          }
          if (!tracks.includes(t)) return;
          if ($('mode').value === 'tempo') await prepareTempos(tracks.map(x => x === t ? {...t, asset:item.id} : x));
          if (!tracks.includes(t)) return;
          t.asset = item.id; t.name = item.name; t.buffer = buffer;
          restartSources(); renderTracks(); status('Instrument variation changed; musical position preserved.');
        } finally { loading = false; }
      });
      title.append(choice);
    }
    const stageLabel = field('label', {textContent: 'Entry stage'}), select = field('select');
    names.forEach((name, i) => select.append(field('option', {textContent: name, value: i})));
    select.value = t.stage; select.onchange = () => { t.stage = Number(select.value); applyMix(); }; stageLabel.append(select);
    const volumeLabel = field('label', {textContent: 'Level'}), volume = field('input', {type: 'range', min: 0, max: 1, step: .01, value: t.volume}), volumeValue = field('output', {textContent: Math.round(t.volume * 100) + '%'});
    volume.oninput = () => { t.volume = Number(volume.value); volumeValue.textContent = Math.round(t.volume * 100) + '%'; applyMix(); }; volumeLabel.append(volume, volumeValue);
    row.append(title, stageLabel, volumeLabel);
    for (const [key, label] of [['trimStart', 'Loop in, s'], ['trimEnd', 'Loop out, s']]) {
      const l = field('label', {textContent: label}), input = field('input', {type: 'number', min: 0, max: t.buffer.duration, step: .01, value: t[key].toFixed(2)});
      input.onchange = () => {
        if ($('mode').value === 'tempo') { input.value = t[key]; status('Switch to fixed-tempo layers before editing loop trims.', true); return; }
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
  if ($('mode').value === 'tempo') throw new Error('Switch to fixed-tempo layers before adding recordings.');
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
    family: item.family, run: item.run, role: item.state_index,
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
  if (data.schema !== 'bmt-audition-1' || !Array.isArray(data.tracks) || data.tracks.length > 12 || !['arrangement', 'layers', 'manual', 'tempo'].includes(data.mode)) throw new Error('Unsupported audition setup');
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
  $('master').dispatchEvent(new Event('input')); $('mode').value = data.mode === 'tempo' ? 'layers' : data.mode; updateMode();
  streak = data.streak; position = data.position; recovery = 0;
  for (const t of data.tracks) {
    const item = catalog.find(i => i.id === t.asset) || {id: t.asset, name: t.asset.replace('local:', ''), kind: 'imported audio'};
    const settings = {...t}; delete settings.asset;
    await addRecording(item, null, settings);
    const last = tracks.at(-1);
    if (last.trimEnd > last.buffer.duration + .001) { tracks.pop(); renderTracks(); throw new Error('Loop range exceeds recording duration'); }
  }
  if (data.mode === 'tempo') { await prepareTempos(); $('mode').value = 'tempo'; updateMode(); }
  renderTime(); status('Setup loaded. Press Play to audition.');
}
function updateMode() {
  $('modeHelp').textContent = {arrangement: 'Assign one arrangement to each stage. Missing stages hold the nearest lower available stage. The first added take wins ties.', layers: 'Selected layers enter cumulatively at their assigned stage. Use aligned stems for musical synchronization.', manual: 'All enabled tracks play together. Solo isolates selected tracks. Clean streak is a reference only in this mode.'}[$('mode').value];
  if ($('mode').value === 'tempo') $('modeHelp').textContent = 'Same score and instrument choices; more parts and faster tempo at each state. 90 → 102 → 114 → 126 → 138 → 150 BPM. Original pitch; phrase position continues. Playback position is score time at 120 BPM.';
  if ($('mode').value === 'tempo') tempoNotice();
  else if (tracks.length && tracks.every(t => t.family === 'shared_road_r3')) $('warning').textContent = 'R3: isolated instruments share one 120 BPM score and 16-second loop. Musical taste and transitions still need your listening review.';
  applyMix();
}
function tempoNotice() {
  $('warning').textContent = 'Evolving tempo: the same 32-beat score is rendered at six tempos, with original pitch. Track details below identify the 120 BPM source parts. Tempo changes preserve phrase position with a short crossfade; listening review remains pending.';
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
$('mode').onchange = guard(async () => {
  if ($('mode').value === 'tempo') {
    try { await prepareTempos(); } catch (error) { $('mode').value = 'layers'; updateMode(); throw error; }
  }
  updateMode();
});
$('evolve').onclick = guard(async () => {
  if (loading) return;
  if (!tracks.length || tracks.some(t => t.family !== 'shared_road_r3')) await document.querySelector('[data-r3="0"]').onclick();
  loading = true;
  try { await prepareTempos(); $('mode').value = 'tempo'; updateMode(); status('Evolving tempo ready. Press Play and move through the states.'); }
  finally { loading = false; }
});
$('refresh').onclick = guard(refresh); $('recording').onchange = recordingInfo;
const iterationControls = field('div', {className:'buttons'});
let previousR2 = [];
for (const [label, choice] of [['R2 · All A', 1], ['R2 · All B', 2], ['R2 · New drive', 0]]) {
  const button = field('button', {className:'small', textContent:label});
  button.dataset.r2 = choice;
  button.onclick = guard(async () => {
    if (loading) return;
    loading = true;
    try {
      await refresh();
      const available = catalog.filter(i => i.family === 'night_signal_r2_review');
      // Choose one complete batch; never silently combine different revisions.
      const run = available.map(i => i.run).sort().at(-1);
      const bank = available.filter(i => i.run === run);
      const options = Array.from({length:6}, (_, stage) => bank.filter(i => i.state_index === stage));
      if (options.some(items => items.length !== 2)) throw new Error('The complete R2 review bank is not ready yet.');
      const random = crypto.getRandomValues(new Uint32Array(6));
      const choices = options.map((_, stage) => choice || 1 + random[stage] % 2);
      if (!choice && choices.every((v, i) => v === previousR2[i])) {
        const change = random[0] % 6; choices[change] = 3 - choices[change];
      }
      const selection = options.map((items, stage) => items.find(i => i.variant === choices[stage]));
      $('clear').click(); streak = 0; recovery = 0; $('mode').value = 'arrangement'; updateMode();
      for (const item of selection) await addRecording(item);
      previousR2 = choices;
      status('R2 stages: ' + selection.map(i => i.variant === 1 ? 'A' : 'B').join(' / ') + '. Choices stay fixed until you load another drive.');
    } finally { loading = false; }
  });
  iterationControls.append(button);
}
$('pair').before(iterationControls);
let previousR3 = [];
for (const [label, choice] of [['R3 · New drive', 0], ['All A', 1], ['All B', 2], ['All C', 3]]) {
  const button = field('button', {className:choice ? 'small' : 'primary', textContent:label});
  button.dataset.r3 = choice;
  button.onclick = guard(async () => {
    if (loading) return;
    loading = true;
    try {
      await refresh();
      const available = catalog.filter(i => i.family === 'shared_road_r3');
      const run = available.map(i => i.run).sort().at(-1);
      const options = Array.from({length:6}, (_, stage) => available.filter(i => i.run === run && i.state_index === stage));
      if (options.some(items => items.length !== 3 || new Set(items.map(i => i.variant)).size !== 3)) throw new Error('The complete R3 instrument bank is not available.');
      const random = crypto.getRandomValues(new Uint32Array(6));
      const choices = options.map((_, stage) => choice || 1 + random[stage] % 3);
      if (!choice && choices.every((v,i) => v === previousR3[i])) choices[random[0] % 6] = choices[random[0] % 6] % 3 + 1;
      const selected = options.map((items,stage) => items.find(i => i.variant === choices[stage]));
      $('clear').click(); streak = 0; recovery = 0; $('mode').value = 'layers'; updateMode();
      for (const item of selected) await addRecording(item, null, {volume:1});
      previousR3 = choices;
      status('R3 instruments: ' + choices.map(v => 'ABC'[v-1]).join(' / ') + '. Press Play, then scrub the streak. Choices stay fixed for this drive.');
    } finally { loading = false; }
  });
  $('r3Controls').append(button);
}
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
