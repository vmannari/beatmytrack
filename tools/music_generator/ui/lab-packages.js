/* Package-first selection. Draws are fixed until the next New drive action. */
let packageSnapshot, currentPackageDraw = null;
function setPackageLock(locked) {
  for (const id of ['add', 'audition', 'files', 'recording', 'mode', 'labStateCount']) $(id).disabled = locked;
  document.querySelector('.lab .library').hidden = locked;
  document.querySelector('.lab .workspace').classList.toggle('package-loaded', locked);
  document.querySelectorAll('#tracks select, #tracks button').forEach(control => control.disabled = locked);
  $('leavePackage').hidden = !locked;
}
const clearAudition = $('clear').onclick;
$('clear').onclick = () => { currentPackageDraw = null; clearAudition(); setPackageLock(false); $('packageSelection').textContent = 'Choose a package and press New drive to draw from its pools.'; };
$('leavePackage').onclick = () => { currentPackageDraw = null; setPackageLock(false); $('packageSelection').textContent = 'Free mix. Add recordings and change states freely.'; };
const randomIndex = length => {
  const ceiling = Math.floor(0x100000000 / length) * length;
  let value; do { value = crypto.getRandomValues(new Uint32Array(1))[0]; } while (value >= ceiling);
  return value % length;
};
async function refreshPackages() {
  packageSnapshot = await StudioUI.getSnapshot(); StudioUI.update(packageSnapshot);
  const select = $('packageSelect'), previous = select.value;
  select.replaceChildren(new Option('Choose a saved package…', ''), new Option('Random ready package', '*'));
  for (const p of packageSnapshot.packages) {
    const option = new Option(`${p.name} · ${p.states.length} states${p.ready ? '' : ' · incomplete pools'}`, p.id); select.append(option);
  }
  select.value = [...select.options].some(o => o.value === previous) ? previous : '';
}
$('packageSelect').onchange = () => {
  $('editPackage').href = $('packageSelect').value && $('packageSelect').value !== '*' ? `/packages.html?package=${$('packageSelect').value}` : '/packages.html';
  $('packageError').hidden = true;
};
$('packageDraw').onclick = async () => {
  if (loading) return;
  loading = true; $('packageDraw').disabled = true; $('packageError').hidden = true;
  try {
    const requested = $('packageSelect').value;
    await refreshPackages();
    const ready = packageSnapshot.packages.filter(p => p.ready);
    const pack = requested === '*' ? ready[randomIndex(ready.length || 1)] : packageSnapshot.packages.find(p => p.id === requested);
    if (!pack) throw new Error('Choose a saved soundtrack with complete pools first.');
    if (!pack.ready) throw new Error(pack.issues.join(' '));
    await refresh();
    const picks = pack.states.map(s => s.pool[randomIndex(s.pool.length)]);
    // Avoid an identical consecutive draw when this package offers alternatives.
    if (currentPackageDraw?.package === pack.id && picks.every((a, i) => currentPackageDraw.assets[i] === a)) {
      const changeable = pack.states.map((s, i) => s.pool.length > 1 ? i : -1).filter(i => i >= 0);
      if (changeable.length) { const i = changeable[randomIndex(changeable.length)]; const alternatives = pack.states[i].pool.filter(a => a !== picks[i]); picks[i] = alternatives[randomIndex(alternatives.length)]; }
    }
    const selected = picks.map(asset => catalog.find(t => t.id === asset));
    if (selected.some(t => !t)) throw new Error('A pool recording was deleted or is unavailable. Edit the package pools and try again.');
    // Decode every chosen track before replacing the current audition.
    for (const item of selected) {
      if (buffers.has(item.id)) continue;
      const response = await fetch(item.url, {signal: AbortSignal.timeout(60000)});
      if (!response.ok) throw new Error('Could not load ' + item.name);
      const decoded = await ensureAudio().decodeAudioData(await response.arrayBuffer());
      if (decoded.duration < .04) throw new Error('Recording is too short: ' + item.name);
      buffers.set(item.id, decoded);
    }
    $('clear').click(); $('mode').value = pack.mode; setStateNames(pack.states.map(s => s.name)); streak = 0; recovery = 0; updateMode();
    for (let i = 0; i < selected.length; i++) await addRecording(selected[i], null, {stage: i});
    currentPackageDraw = {package: pack.id, assets: picks.slice()};
    setPackageLock(true);
    $('packageSelection').textContent = `${pack.name} · ${pack.mode === 'layers' ? 'Layer stack' : 'Switch tracks'} · ${pack.states.length} states. These choices stay fixed until New drive.`;
    $('editPackage').href = `/packages.html?package=${pack.id}`;
    status('Soundtrack loaded. Press Play to audition this drive.');
  } catch (e) { $('packageError').textContent = e.message; $('packageError').hidden = false; }
  finally { loading = false; $('packageDraw').disabled = false; }
};
refreshPackages().then(() => {
  if (!tracks.length && !loading) setStateNames(packageSnapshot.states);
  const requested = new URLSearchParams(location.search).get('package');
  if (requested && packageSnapshot.packages.some(p => p.id === requested)) { $('packageSelect').value = requested; $('packageSelect').onchange(); }
}).catch(e => { $('packageError').textContent = e.message; $('packageError').hidden = false; });
