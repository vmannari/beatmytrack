'use strict';
// The managed provider owns Google OAuth, TOTP secrets and verification.
window.StudioSignIn = (() => {
 let sdkPromise, auth, sdk, flow=0;
 const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 async function load(config) {
  sdkPromise ??= Promise.all([
   import('https://www.gstatic.com/firebasejs/12.4.0/firebase-app.js'),
   import('https://www.gstatic.com/firebasejs/12.4.0/firebase-auth.js')
  ]);
  const [app, functions] = await sdkPromise;
  sdk = functions;
  if (!auth) {
   auth = sdk.initializeAuth(app.initializeApp({apiKey:config.apiKey,authDomain:config.authDomain,
    projectId:config.projectId}, 'bmt-studio'), {persistence:sdk.inMemoryPersistence,
    popupRedirectResolver:sdk.browserPopupRedirectResolver});
   auth.tenantId = config.tenantId;
  }
 }
 async function lock() { flow++; if(auth) await sdk.signOut(auth); }
 function errorText(error) {
  return ({'auth/popup-closed-by-user':'Sign-in was cancelled. You can try again.',
   'auth/popup-blocked':'Allow the Google sign-in popup, then try again.',
   'auth/invalid-verification-code':'That code was not accepted. Enter the current code from your authenticator.',
   'auth/code-expired':'That code expired. Enter the current code from your authenticator.',
   'auth/too-many-requests':'Too many attempts. Wait a moment before trying again.',
   'STAFF_NOT_AUTHORISED':'This Google account does not have Studio access.',
   'STAFF_ACCESS_DISABLED':'Studio access for this account is disabled.'})[error.code || error.message]
   || 'Sign-in could not be completed. Try again. If it continues, check the Studio identity configuration.';
 }
 async function mount(container, complete, message='', onPolicy=null) {
  const mine=++flow;
  const current=()=>flow===mine && container.isConnected;
  const fail=error=>{if(current()){const p=container.querySelector('[role="alert"]');if(p){p.hidden=false;p.textContent=errorText(error);}}};
  try {
   const response=await fetch('/v1/admin/auth/config',{cache:'no-store'});
   if(!response.ok)throw Error('config');
   const config=await response.json();
   if(!current())return;
   if(onPolicy)onPolicy(config.reporting);
   if(!config.configured){
    if(!config.legacy_enabled)container.innerHTML='<p>Studio browser sign-in is not configured. Contact the service owner.</p>';
    return;
   }
   container.innerHTML='<p>Loading secure sign-in…</p>';
   await load(config);
   if(!current())return;
   container.innerHTML=`<p>Use your authorised Google account and an authenticator app.</p><button type="button" class="btn btn-primary" id="staff-google">Sign in with Google</button><p role="alert" class="console-error" hidden></p><p class="console-note">${escape(message)}</p>`;
   const google=container.querySelector('#staff-google');
   const codes=(title,description,verify)=>{
    if(!current())return;
    container.innerHTML=`<h3>${escape(title)}</h3>${description}<form id="staff-code"><label for="staff-otp">Authenticator code</label><input id="staff-otp" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" minlength="6" required><div class="console-actions"><button class="btn btn-primary">Continue</button><button type="button" id="staff-cancel" class="btn">Cancel</button></div></form><p role="alert" class="console-error" hidden></p>`;
    container.querySelector('#staff-cancel').onclick=async()=>{await lock();mount(container,complete);};
    container.querySelector('#staff-otp').focus();
    container.querySelector('form').onsubmit=async event=>{
     event.preventDefault();
     const button=container.querySelector('button');button.disabled=true;
     const input=container.querySelector('#staff-otp'), value=input.value;input.value='';
     try{await verify(value);}catch(error){fail(error);}finally{if(current())button.disabled=false;}
    };
   };
   const accept=async user=>{
    if(!current())return;
    const token=await user.getIdToken(true);
    if(!current())return;
    const eligible=await fetch('/v1/admin/auth/eligibility',{method:'POST',
     headers:{'Content-Type':'application/json'},body:JSON.stringify({id_token:token})});
    const result=await eligible.json();
    if(!current())return;
    if(!eligible.ok){await sdk.signOut(auth);throw Error(result.detail);}
    if(result.mfa_verified){await complete(token);return;}
    if(sdk.multiFactor(user).enrolledFactors.length){
     await sdk.signOut(auth);mount(container,complete,'Sign in again and enter your authenticator code.');return;
    }
    const session=await sdk.multiFactor(user).getSession();
    const secret=await sdk.TotpMultiFactorGenerator.generateSecret(session);
    if(!current())return;
    codes('Set up your authenticator',`<p>Add a time-based account named <strong>Beat my track Studio</strong> in your authenticator app. Enter this setup key:</p><p><code>${escape(secret.secretKey)}</code></p><p>Then enter its six-digit code below. Keep the setup key private.</p>`,async code=>{
     await sdk.multiFactor(user).enroll(sdk.TotpMultiFactorGenerator.assertionForEnrollment(secret,code),'Studio authenticator');
     if(!current())return;
     await sdk.signOut(auth);
     mount(container,complete,'Authenticator added. Sign in once more to open Studio.');
    });
   };
   google.onclick=async()=>{
    google.disabled=true;
    const provider=new sdk.GoogleAuthProvider();
    provider.setCustomParameters({prompt:'select_account',...(config.loginHint?{login_hint:config.loginHint}:{})});
    try{await accept((await sdk.signInWithPopup(auth,provider)).user);}
    catch(error){
     if(!current())return;
     if(error.code==='auth/multi-factor-auth-required'){
      const resolver=sdk.getMultiFactorResolver(auth,error);
      const hints=resolver.hints.filter(h=>h.factorId===sdk.TotpMultiFactorGenerator.FACTOR_ID);
      if(hints.length!==1){fail(Error('totp'));google.disabled=false;return;}
      codes('Verify your sign-in','<p>Enter the current code from your Studio authenticator.</p>',async code=>{
       const credential=await resolver.resolveSignIn(sdk.TotpMultiFactorGenerator.assertionForSignIn(hints[0].uid,code));
       await accept(credential.user);
      });
     }else{fail(error);google.disabled=false;}
    }
   };
  }catch(error){if(current()){container.innerHTML='<p role="alert" class="console-error"></p>';fail(error);}}
 }
 return {mount,lock};
})();
