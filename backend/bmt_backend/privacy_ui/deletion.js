'use strict';
(() => {
  const byId = id => document.getElementById(id);
  const signin = byId('signin'), remove = byId('delete'), status = byId('status');
  let token = '', operation = '', busy = false;
  const say = text => { status.textContent = text; };
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
    busy = true; signin.disabled = true; byId('confirm').hidden = true;
    // Open synchronously for popup rules. Game credentials/deletion tokens never enter page URLs/storage.
    const popup = window.open('about:blank', '_blank');
    try {
      const start = await post('/v1/auth/google/browser/start', {});
      const target = new URL(start.browser_url, location.origin);
      if (target.origin !== location.origin || target.pathname !== '/v1/auth/google/browser') throw new Error('Verification address is unavailable.');
      token = start.poll_token; operation = crypto.randomUUID();
      if (!popup) throw new Error('Allow the verification window, then retry.');
      popup.opener = null; popup.location.replace(target.href);
      say('Finish verification in the Google window.');
      const deadline = Date.now() + 300000;
      while (Date.now() < deadline) {
        await new Promise(resolve => setTimeout(resolve, 5000));
        const session = await post('/v1/privacy/web-session', { token });
        if (session.status === 'ready') {
          byId('name').textContent = session.display_name;
          byId('agreement').checked = false; remove.disabled = true;
          byId('confirm').hidden = false; say('Verified. Review what remains, then confirm deletion.');
          return;
        }
      }
      throw new Error('Verification expired. Verify with Google again.');
    } catch (error) { say(error.message || 'Verification failed. Please retry.'); }
    finally { busy = false; signin.disabled = false; }
  });
  byId('agreement').addEventListener('change', () => { remove.disabled = busy || !byId('agreement').checked; });
  remove.addEventListener('click', async () => {
    if (busy || !token || !byId('agreement').checked) return;
    busy = true; remove.disabled = true; signin.disabled = true;
    try {
      await post('/v1/privacy/web-delete', { token, request_id: operation, confirmation: 'DELETE' });
      byId('confirm').hidden = true; token = '';
      say('Account removed. Private data cleanup is scheduled. Tracks and historical standings remain under Removed account.');
    } catch (error) { say(error.message || 'Deletion could not be confirmed. Retry with the same verification.'); }
    finally { busy = false; signin.disabled = false; remove.disabled = !byId('agreement').checked; }
  });
})();
