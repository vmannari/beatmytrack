'use strict';
(() => {
  const byId = id => document.getElementById(id);
  const signin = byId('signin'), remove = byId('delete'), status = byId('status');
  let token = '', operation = '', busy = false, previewReady = false;
  const say = text => { status.textContent = text; };
  function benefitLines(value) {
    const whole = number => Number.isSafeInteger(number) && number >= 0;
    if (!value || value.schema_version !== 1 || typeof value.player_id !== 'string' || !value.player_id ||
        !['server_now', 'publishing_slots', 'coins', 'banked_resumes', 'cosmetic_unlocks', 'pending_purchases', 'ad_free_until'].every(key => whole(value[key])) ||
        value.player_id.length > 256 || !value.server_now || value.server_now > 253402300799 || value.ad_free_until > 253402300799 || typeof value.ad_free !== 'boolean' || typeof value.ad_free_forever !== 'boolean' ||
        value.ad_free !== (value.ad_free_forever || value.ad_free_until > value.server_now)) {
      throw new Error('Could not load your remaining benefits. Verify again before deleting your account.');
    }
    const lines = [`Publishing slots: ${value.publishing_slots}`, `Coins: ${value.coins}`,
      `Banked resumes: ${value.banked_resumes}`, `Online cosmetic unlocks: ${value.cosmetic_unlocks}`];
    if (value.ad_free_forever) lines.push('Ad-free access: active, with no scheduled expiry');
    else if (value.ad_free) {
      const hours = Math.ceil((value.ad_free_until - value.server_now) / 3600);
      lines.push(`Ad-free access: ${Math.floor(hours / 24)} days, ${hours % 24} hours remaining (rounded up); expires ${new Date(value.ad_free_until * 1000).toISOString().replace('T', ' ').replace('.000Z', ' UTC')}`);
    } else lines.push('Ad-free access: none active');
    if (value.pending_purchases) lines.push(`Pending purchases: ${value.pending_purchases}. Deletion does not cancel a store payment. Contact support about outstanding purchases.`);
    return lines;
  }
  const errors = { ACCOUNT_NOT_FOUND: 'No Beat my track account exists for that Google identity.', LOGIN_EXPIRED: 'Verification expired. Verify with Google again.', SIGN_IN_PENDING: 'Finish Google verification first.', RATE_LIMITED: 'Please wait a minute, then retry.', IDENTITY_PROVIDER_UNAVAILABLE: 'Google verification is temporarily unavailable. Please retry.' };
  async function post(path, body) {
    const controller = new AbortController(), timeout = setTimeout(() => controller.abort(), 15000);
    try {
      const response = await fetch(path, { method: 'POST', credentials: 'omit', cache: 'no-store', signal: controller.signal,
        headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      const value = await response.json();
      if (!response.ok) throw new Error(errors[value.detail] || 'Request could not complete. Please retry.');
      return value;
    } catch (error) {
      if (error.name === 'AbortError') throw new Error('Request timed out. Retry with the same verification.');
      if (error instanceof TypeError) throw new Error('Could not connect. Check your connection and retry.');
      throw error;
    } finally { clearTimeout(timeout); }
  }
  signin.addEventListener('click', async () => {
    if (busy) return;
    busy = true; previewReady = false; signin.disabled = true; remove.disabled = true; byId('agreement').checked = false; byId('confirm').hidden = true;
    token = ''; operation = '';
    // Open synchronously for popup rules. Game credentials/deletion tokens never enter page URLs/storage.
    const popup = window.open('about:blank', '_blank');
    try {
      if (!popup) throw new Error('Allow the verification window, then retry.');
      const start = await post('/v1/auth/google/browser/start', {});
      token = start.poll_token; operation = crypto.randomUUID();
      const target = new URL(start.browser_url, location.origin);
      if (target.origin !== location.origin || target.pathname !== '/v1/auth/google/browser') throw new Error('Verification address is unavailable.');
      if (!popup.closed) { popup.opener = null; popup.location.replace(target.href); }
      say('Finish verification in the Google window.');
      const deadline = Date.now() + 300000;
      let nextPoll = Date.now() + 5000;
      while (Date.now() < deadline) {
        await new Promise(resolve => setTimeout(resolve, 1000));
        const closed = popup.closed;
        if (!closed && Date.now() < nextPoll) continue;
        // A user can close the window immediately after completing Google sign-in.
        // Check the server first so a successful verification is not discarded.
        const session = await post('/v1/privacy/web-session', { token });
        if (session.status === 'ready') {
          const lines = benefitLines(session.deletion_preview);
          byId('benefits').replaceChildren(...lines.map(text => {
            const item = document.createElement('li'); item.textContent = text; return item;
          }));
          byId('name').textContent = session.display_name;
          previewReady = true;
          byId('agreement').checked = false; remove.disabled = true;
          byId('confirm').hidden = false; say('Verified. Review what remains, then confirm deletion.');
          return;
        }
        if (closed) throw new Error('Verification window closed. You can try again.');
        nextPoll = Date.now() + 5000;
      }
      throw new Error('Verification expired. Verify with Google again.');
    } catch (error) {
      if (popup && !popup.closed) popup.close();
      // Best-effort invalidation does not delay retry; the server also expires the token.
      if (token) fetch('/v1/auth/google/browser/cancel', { method: 'POST', credentials: 'omit', cache: 'no-store',
        headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token }) }).catch(() => {});
      token = ''; operation = '';
      say(error.message || 'Verification failed. Please retry.');
    }
    finally { busy = false; signin.disabled = false; }
  });
  byId('agreement').addEventListener('change', () => { remove.disabled = busy || !previewReady || !byId('agreement').checked; });
  remove.addEventListener('click', async () => {
    if (busy || !token || !previewReady || !byId('agreement').checked) return;
    busy = true; remove.disabled = true; signin.disabled = true;
    try {
      await post('/v1/privacy/web-delete', { token, request_id: operation, confirmation: 'DELETE' });
      byId('confirm').hidden = true; token = ''; previewReady = false;
      say('Account removed. Private data cleanup is scheduled. Tracks and historical standings remain under Removed account.');
    } catch (error) { say(error.message || 'Deletion could not be confirmed. Retry with the same verification.'); }
    finally { busy = false; signin.disabled = false; remove.disabled = !previewReady || !byId('agreement').checked; }
  });
})();
