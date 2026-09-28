/* Shared navigation and local API for every music studio workspace. */
(() => {
  const host = document.getElementById('studioSidebar');
  const page = document.body.dataset.page || 'studio';
  const home = page === 'studio';
  if (host) {
    host.innerHTML = `<a class="brand" href="/" aria-label="Music studio home"><span class="brand-mark" aria-hidden="true">bmt</span><span>BEAT MY TRACK<small>Music studio</small></span></a>
      <div class="nav-caption">WORKSPACE</div><nav aria-label="Workspace">
      ${home ? '<button data-view="create" class="nav-item"><span aria-hidden="true">＋</span>Create music</button><button data-view="library" class="nav-item"><span aria-hidden="true">▤</span>Your library <b id="libraryCount">0</b></button>' : '<a class="nav-item" href="/"><span aria-hidden="true">＋</span>Create music</a><a class="nav-item" href="/#library"><span aria-hidden="true">▤</span>Your library <b id="libraryCount">0</b></a>'}
      <a class="nav-item ${page === 'packages' ? 'active' : ''}" href="/packages.html" ${page === 'packages' ? 'aria-current="page"' : ''}><span aria-hidden="true">▧</span>Soundtracks</a>
      <a class="nav-item ${page === 'lab' ? 'active' : ''}" href="/lab.html" ${page === 'lab' ? 'aria-current="page"' : ''}><span aria-hidden="true">≋</span>Mix lab</a></nav>
      <div class="nav-caption state-caption">LIBRARY STATES <a href="/states.html" aria-label="Manage library states">Edit</a></div><div id="stateNav" class="state-nav"></div>
      <a class="nav-item settings-link ${page === 'states' ? 'active' : ''}" href="/states.html">Manage states</a>
      <div class="sidebar-note"><span class="local-dot"></span> Made on your machine<p>Local music. Your collection.<br>Your combinations.</p></div>`;
  }
  let token = '';
  const api = async (path, body) => {
    if (body && !token) await getSnapshot();
    const response = await fetch(path, {method: body ? 'POST' : 'GET', headers: body ? {'Content-Type': 'application/json', 'X-Workbench-Token': token} : {}, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(15000)});
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || 'The music studio could not complete this action.');
    return result;
  };
  async function getSnapshot() { const value = await api('/api/workbench'); token = value.token; return value; }
  function update(data, onState) {
    const count = document.getElementById('libraryCount'); if (count) count.textContent = data.tracks.length;
    const list = document.getElementById('stateNav'); if (!list) return;
    list.replaceChildren();
    (data.states || []).forEach((name, index) => {
      const link = document.createElement('a'); link.href = `/?state=${index}#library`;
      const number = document.createElement('span'); number.className = 'state-number'; number.textContent = String(index + 1).padStart(2, '0');
      const label = document.createElement('span'); label.textContent = name;
      const count = document.createElement('b'); count.textContent = data.tracks.filter(t => t.state_index === index).length;
      link.append(number, label, count);
      if (onState) link.onclick = event => { event.preventDefault(); onState(index); };
      list.append(link);
    });
  }
  function notice(message, error = false) {
    const output = document.getElementById('pageNotice');
    if (output) { output.hidden = false; output.textContent = message; output.className = error ? 'inline-error' : 'page-notice'; }
  }
  window.StudioUI = {api, getSnapshot, update, notice};
})();
