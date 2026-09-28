'use strict';
let stateDraft = [], originalCount = 0;
const countInput = document.getElementById('stateCount');
function renderNames() {
  const host = document.getElementById('stateNames'); host.replaceChildren();
  stateDraft.forEach((name, i) => {
    const label = document.createElement('label'); label.textContent = `State ${i + 1}`;
    const input = document.createElement('input'); input.value = name; input.required = true; input.maxLength = 40; input.dataset.state = i;
    input.oninput = () => stateDraft[i] = input.value;
    label.append(input); host.append(label);
  });
}
countInput.onchange = () => {
  if (!countInput.reportValidity()) return;
  const count = Number(countInput.value);
  if (count === stateDraft.length) return;
  stateDraft = Array.from({length: count}, (_, i) => stateDraft[i] || `State ${i + 1}`); renderNames();
  document.getElementById('stateImpact').textContent = count < originalCount ? 'Removed states will become Unassigned on affected library tracks and pending takes. Package states are unchanged.' : 'Existing packages keep their own state names and pools.';
};
document.getElementById('statesForm').onsubmit = async event => {
  event.preventDefault(); const button = document.getElementById('saveStates'); button.disabled = true;
  try { await StudioUI.api('/api/states', {states: stateDraft}); const data = await StudioUI.getSnapshot(); StudioUI.update(data); originalCount = data.states.length; StudioUI.notice('Library states saved.'); }
  catch (e) { StudioUI.notice(e.message, true); } finally { button.disabled = false; }
};
StudioUI.getSnapshot().then(data => { stateDraft = data.states.slice(); originalCount = stateDraft.length; countInput.value = stateDraft.length; StudioUI.update(data); renderNames(); }).catch(e => StudioUI.notice(e.message, true));
