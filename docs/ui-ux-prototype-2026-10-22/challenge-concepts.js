/* Local design alternatives. Exact completed-race identity is kept separately
   from menu selections. These controls never create a live challenge. */
const challengeLab={
 variant:'invitation',context:'menu',source:'challenges',result:null,awaitingResult:false,
 draft:{track:0,car:0,kind:'Beat my time',duration:'7 days',tries:'Unlimited',name:'',preset:'duel'},
 rulesDraft:null,copyText:'',lastCreated:null
};
const challengeVariants={
 invitation:{label:'A · Invitation',description:'Compose the dare. Keep the rules in the background.'},
 showdown:{label:'B · Showdown cards',description:'Pick a format. The invitation takes shape around that choice.'},
 drive:{label:'C · Drive first',description:'Start with the fun part. The finished race becomes the invitation.'}
};
const showdownPresets={
 duel:{title:'A friendly duel',copy:'One rival. One time to chase.',kind:'Beat my time',duration:'7 days',tries:'Unlimited',theme:'pine'},
 weekend:{title:'Weekend grid',copy:'Bring the crew. Find out who’s quickest.',kind:'Group challenge',duration:'3 days',tries:'Unlimited',theme:'night'},
 shots:{title:'Three shots',copy:'Make every attempt count.',kind:'Group challenge',duration:'24 hours',tries:'3',theme:'desert'}
};
function ccTrack(){return tracks[challengeLab.result?.track??challengeLab.draft.track];}
function ccCar(){return cars[challengeLab.result?.car??challengeLab.draft.car];}
function ccTrackIndex(){return challengeLab.result?.track??challengeLab.draft.track;}
function ccName(){return challengeLab.draft.name.trim()||`${challengeLab.draft.kind==='Beat my time'?'Beat my time':'Race the crew'} · ${ccTrack().name}`;}
function ccDuration(value=challengeLab.draft.duration){return value==='24 hours'?'24 hours':value;}
function ccTries(value=challengeLab.draft.tries){return value==='Unlimited'?'Unlimited tries':`${value} ${value==='1'?'try':'tries'} per driver`;}
function ccAudience(){return challengeLab.draft.kind==='Beat my time'?'One rival':'Up to 20 drivers';}
function ccRuleSentence(draft=challengeLab.draft){return `${ccDuration(draft.duration)} · ${ccTries(draft.tries)}`;}
function ccResultFixture(){return state.completedSampleResult?{...state.completedSampleResult}:{track:0,car:0,time:'01:23.407',raceId:'illustrative-completed-race'};}
function openChallengeConcept(context){
 const source=state.screen;
 const postRace=context==='result'||context===undefined&&['results','analysis'].includes(source);
 challengeLab.source=source==='challenge-create'?'challenges':source;
 challengeLab.context=postRace?'result':'menu';
 challengeLab.result=postRace?ccResultFixture():null;
 challengeLab.awaitingResult=false;
 challengeLab.draft={track:challengeLab.result?.track??state.track,car:challengeLab.result?.car??state.selectedCar,kind:'Beat my time',duration:'7 days',tries:'Unlimited',name:'',preset:'duel'};
 closeModal();navigate('challenge-create');
}
function ccAudienceChoices(compact=false){return `<div class="audience-options ${compact?'compact':''}" role="group" aria-label="Who will race?">${[['Beat my time','person','One rival','A head-to-head dare'],['Group challenge','people','A group','Bring up to 20 drivers']].map(([kind,i,title,copy])=>`<button class="audience-choice ${challengeLab.draft.kind===kind?'active':''}" data-action="cc-kind" data-value="${kind}" aria-pressed="${challengeLab.draft.kind===kind}">${icon(i)}<strong>${title}</strong>${compact?'':`<small>${copy}</small>`}</button>`).join('')}</div>`;}
function ccEditableContext(){if(challengeLab.result)return `<div class="creation-context-strip"><p class="creation-lock">${icon('shield')}From this race · track and car fixed</p></div>`;return `<div class="creation-context-strip"><p>THE RACE</p>${button(ccTrack().name+' '+icon('chevron'),'cc-track','quiet small')}${button(ccCar().name+' '+icon('chevron'),'cc-car','quiet small')}</div>`;}
function ccRename(){return `<div class="creation-title-link"><span>${escapeHtml(ccName())}</span>${button(icon('brush')+'Rename','cc-rename','quiet small')}</div>`;}
function ccFooter(){return `<footer class="creation-footer"><p class="creation-footer-copy">${challengeLab.result?'Share the invitation when you’re ready.':'First, drive the race that sets the target.'}</p>${button((challengeLab.result?'Create invitation':'Race to set the time')+' '+icon('arrow'),'cc-primary','primary')}</footer>`;}
function ccTopline(){return `<div class="creation-topline"><p class="eyebrow">CHALLENGE CLUB / CREATE</p>${button(icon('back')+'Back','cc-back','quiet small')}</div>`;}
function ccPoster(){return `<article class="invite-poster">${scene(ccTrack().theme)}<span class="poster-kicker">${icon('flag')}YOUR LINE. THEIR TURN.</span>${challengeLab.result?`<span class="poster-stamp">${icon('check')}FROM YOUR RACE</span>`:''}<div class="poster-route">${route(ccTrackIndex())}</div><h2 class="poster-dare">CAN YOU<br><em>BEAT THIS?</em></h2><div class="poster-time ${challengeLab.result?'':'no-time'}">${challengeLab.result?escapeHtml(challengeLab.result.time):'A time they’ll want<br>to take down.'}</div><p class="poster-time-label">${challengeLab.result?'THE TIME TO BEAT':'YOUR NEXT RACE SETS THE TARGET'}</p><div class="poster-bottom"><div class="poster-track"><h3>${ccTrack().name.toUpperCase()}</h3><p>${ccCar().name} · 5 laps</p></div><span class="poster-brand">BEAT<br><em>MY</em> TRACK</span></div></article>`;}
function invitationConcept(){return `${ccTopline()}<div class="invitation-layout">${ccPoster()}<section class="invite-compose"><div><p class="eyebrow" style="margin-bottom:10px">MAKE IT PERSONAL</p><h1>YOU SET THE PACE.<br>WHO’S NEXT?</h1></div><p class="creation-subtitle">Give someone a reason to take one more run.</p>${ccAudienceChoices()}<div class="creation-easy-rules"><p>${ccDuration()}<span class="rule-dot">·</span>${ccTries()}</p>${button('Change rules','cc-rules','quiet small')}</div>${ccEditableContext()}${ccRename()}</section></div>${ccFooter()}`;}
function showdownSymbols(key){return key==='duel'?`${icon('car')}<span class="versus-glyph">VS</span>${icon('car')}`:key==='weekend'?`${icon('flag')}${icon('people')}`:`<span style="font:58px var(--display);color:var(--yellow)">3</span>${icon('target')}`;}
function showdownConcept(){return `${ccTopline()}<div class="showdown-intro"><h1>PICK YOUR<br>SHOWDOWN.</h1><p>A friendly dare or a little more pressure.<br>Choose the kind of race you want to start.</p></div><div class="showdown-options" role="group" aria-label="Challenge formats">${Object.entries(showdownPresets).map(([key,preset])=>`<button class="showdown-card ${challengeLab.draft.preset===key?'active':''}" data-action="cc-preset" data-value="${key}" aria-pressed="${challengeLab.draft.preset===key}"><span class="showdown-check">${icon('check')}</span><div class="showdown-art">${scene(preset.theme)}<span class="showdown-symbol">${showdownSymbols(key)}</span></div><div class="showdown-copy"><h2>${preset.title}</h2><p>${preset.copy}</p><div class="showdown-facts"><span>${preset.duration}</span><span>${preset.tries==='Unlimited'?'Unlimited tries':'3 tries each'}</span></div></div></button>`).join('')}</div><div class="showdown-track"><div class="showdown-track-art">${scene(ccTrack().theme)}${route(ccTrackIndex())}</div><div class="showdown-track-info"><h3>${ccTrack().name}</h3><p>${ccCar().name} · 5 laps</p>${challengeLab.result?`<p class="creation-lock">${icon('shield')}From your completed race</p>`:button('Change circuit or car','cc-setup','quiet small')}</div><div class="showdown-target"><p>TIME TO BEAT</p><strong class="${challengeLab.result?'':'no-time'}">${challengeLab.result?escapeHtml(challengeLab.result.time):'Your next race<br>sets the target'}</strong></div></div><div class="row between"><p class="small muted">${challengeLab.draft.kind} · ${ccRuleSentence()}</p>${button('Adjust rules','cc-rules','quiet small')}</div>${ccFooter()}`;}
function driveConcept(){const ready=!!challengeLab.result;return `${ccTopline()}<div class="drive-first-progress" aria-label="Challenge progress"><div class="drive-first-step ${ready?'done':'active'}"><strong>${ready?icon('check'):'1'}</strong><span>Choose your circuit</span></div><span class="drive-first-step-line"></span><div class="drive-first-step ${ready?'done':'active'}"><strong>${ready?icon('check'):'2'}</strong><span>Set the time</span></div><span class="drive-first-step-line"></span><div class="drive-first-step ${ready?'active':''}"><strong>3</strong><span>Invite your rivals</span></div></div><section class="drive-first-hero">${scene(ccTrack().theme)}<div class="drive-first-route">${route(ccTrackIndex())}</div><div class="drive-first-copy"><p class="eyebrow">${ready?'YOUR MOVE IS MADE':'IT STARTS WITH A GOOD DRIVE'}</p><h1>${ready?'THAT’S YOUR<br><em>OPENING MOVE.</em>':'SET A TIME.<br>MAKE THEM<br><em>CHASE IT.</em>'}</h1>${ready?`<div class="drive-first-result">${escapeHtml(challengeLab.result.time)}<small>YOUR EXACT RACE · THEIR TIME TO BEAT</small></div>`:`<p class="creation-subtitle">Take five laps. Find your line.<br>Then give your rivals something to chase.</p>`}</div></section><div class="drive-first-bottom"><div class="drive-first-details"><strong>${ccTrack().name}</strong><p>${ccCar().name} · 5 laps</p>${ready?`<span class="creation-lock">${icon('shield')}Track and car fixed to this race</span>`:button('Change circuit or car '+icon('chevron'),'cc-setup','quiet small')}</div>${ready?`<span class="creation-badge">${icon('check')}Ready for an invitation</span>`:`<p class="small muted">We’ll keep the invitation ready.</p>`}</div>${ready?`<div class="drive-first-invite"><div class="row">${[['Beat my time','person','One rival'],['Group challenge','people','A group']].map(([kind,i,title])=>`<button class="audience-choice ${challengeLab.draft.kind===kind?'active':''}" data-action="cc-kind" data-value="${kind}" aria-pressed="${challengeLab.draft.kind===kind}">${icon(i)}<strong>${title}</strong></button>`).join('')}</div>${button(ccRuleSentence()+' '+icon('chevron'),'cc-rules','quiet small')}</div>`:''}<footer class="creation-footer"><div class="creation-footer-copy"><strong>${ready?'Now put it out there.':'Get to the fun part first.'}</strong>${ready?`${ccAudience()} · A link they can race for free.`:'Choose your invitation rules after the drive.'}</div>${button((ready?'Create invitation':'Set my time')+' '+icon('arrow'),'cc-primary','primary')}</footer>`;}
function challengeCreation(){return `<div class="screen-body"><section class="creation-page game-content-enter" data-concept="${challengeLab.variant}">${{invitation:invitationConcept,showdown:showdownConcept,drive:driveConcept}[challengeLab.variant]()}</section></div>`;}
function renderChallengeReview(){const visible=state.screen==='challenge-create';const host=$('#challenge-review');host.hidden=!visible;$('#scenario').disabled=visible;if(visible){const meta=challengeVariants[challengeLab.variant];host.innerHTML=`<section class="concept-review"><div class="concept-review-top"><span class="concept-review-label">COMPARE THE CREATION EXPERIENCE</span><div class="concept-variants" role="group" aria-label="Challenge concept">${Object.entries(challengeVariants).map(([key,value])=>`<button class="concept-switch" data-action="cc-variant" data-value="${key}" aria-pressed="${challengeLab.variant===key}">${value.label}</button>`).join('')}</div></div><div class="concept-review-bottom"><span class="concept-explainer">${meta.description}</span><div class="concept-context"><span>TRY FROM</span><button data-action="cc-context" data-value="menu" aria-pressed="${!challengeLab.result}">Menu</button><button data-action="cc-context" data-value="result" aria-pressed="${!!challengeLab.result}">After a race</button></div></div></section>`;const raceTab=$('.nav-tab[data-value="race"]');raceTab?.classList.add('active');raceTab?.setAttribute('aria-current','page');$('#before-button').textContent='Previous form';$('#screen-label').textContent='CHALLENGE CREATION / '+meta.label.toUpperCase();}else $('#before-button').textContent='Current screen';if(state.screen==='results'&&challengeLab.awaitingResult){const next=$('[data-action="results-next"]');if(next)next.outerHTML=button(challengeLab.variant==='drive'?'Invite your rivals '+icon('arrow'):'Create invitation '+icon('arrow'),'cc-after-race','outline');}}

function ccDialog(title,body,actionsHtml='',cls='',copy=''){
 closeModal();state.modal='challenge-concept';
 $('#modal-root').innerHTML=`<dialog class="${cls}" aria-labelledby="concept-dialog-title"><button class="dialog-close" data-action="close" aria-label="Close dialog">${icon('close')}</button><h2 id="concept-dialog-title">${title}</h2>${copy?`<p class="dialog-copy">${copy}</p>`:''}${body}${actionsHtml?`<div class="dialog-actions">${actionsHtml}</div>`:''}</dialog>`;
 const dialog=$('#modal-root dialog');
 dialog.addEventListener('cancel',event=>{event.preventDefault();closeModal();});
 dialog.addEventListener('keydown',event=>{
  if(event.key!=='Tab')return;
  const controls=$$('button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex="0"]',dialog).filter(el=>el.getClientRects().length);
  if(!controls.length){event.preventDefault();return;}
  const first=controls[0],last=controls.at(-1);
  if(event.shiftKey&&(document.activeElement===first||!dialog.contains(document.activeElement))){event.preventDefault();last.focus();}
  else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}
 });
 dialog.showModal();
}
function ccChipGroup(values,selected,action,label){return `<div class="rule-chips" role="group" aria-label="${label}">${values.map(([value,text])=>`<button class="rule-chip ${selected===value?'active':''}" data-action="${action}" data-value="${value}" aria-pressed="${selected===value}">${text}</button>`).join('')}</div>`;}
function ccRules(){challengeLab.rulesDraft={duration:challengeLab.draft.duration,tries:challengeLab.draft.tries};ccDialog('Give it your kind of pressure.',`<div class="rule-choice-group"><p>How long do they have?</p>${ccChipGroup([['24 hours','24 hours'],['3 days','3 days'],['7 days','7 days']],challengeLab.rulesDraft.duration,'cc-duration','Challenge duration')}</div><div class="rule-choice-group"><p>How many shots at it?</p>${ccChipGroup([['Unlimited','Unlimited'],['1','1'],['3','3'],['5','5']],challengeLab.rulesDraft.tries,'cc-tries','Tries per driver')}</div><p class="rule-summary" id="cc-rule-summary">${ccRuleSentence(challengeLab.rulesDraft)}. <strong>Their best time counts.</strong></p>`,button('Cancel','close','outline')+button('Keep these rules '+icon('check'),'cc-rules-save','primary'),'challenge-rules-dialog');}
function ccUpdateRule(key,value,action){if(!challengeLab.rulesDraft)return;challengeLab.rulesDraft[key]=value;$$(`[data-action="${action}"]`).forEach(el=>{const chosen=el.dataset.value===value;el.classList.toggle('active',chosen);el.setAttribute('aria-pressed',String(chosen));});$('#cc-rule-summary').innerHTML=escapeHtml(ccRuleSentence(challengeLab.rulesDraft))+'. <strong>Their best time counts.</strong>';}
function ccTrackPicker(){if(challengeLab.result)return;ccDialog('Where’s the showdown?',`<div class="challenge-track-picker">${tracks.map((t,i)=>`<button class="challenge-pick ${challengeLab.draft.track===i?'active':''}" data-action="cc-pick-track" data-value="${i}" aria-pressed="${challengeLab.draft.track===i}"><div class="challenge-pick-art">${scene(t.theme)}${route(i)}</div><strong>${t.name}</strong><p>${t.biome} · 5 laps</p></button>`).join('')}</div>`,button('Keep this circuit','close','outline'),'challenge-picker-dialog');}
function ccCarPicker(){if(challengeLab.result)return;ccDialog('Your car for the dare.',`<div class="challenge-car-picker">${cars.map((c,i)=>`<button class="challenge-pick ${challengeLab.draft.car===i?'active':''}" data-action="cc-pick-car" data-value="${i}" aria-pressed="${challengeLab.draft.car===i}">${carImage(i)}<strong>${c.name}</strong><p>${c.character}</p></button>`).join('')}</div>`,button('Keep this car','close','outline'),'challenge-picker-dialog');}
function ccSetup(){if(challengeLab.result)return;ccDialog('Pick the race.',`<div class="unsaved-summary"><div class="row between"><strong>${ccTrack().name}</strong>${button('Choose circuit','cc-track','outline small')}</div><div class="rule"></div><div class="row between"><strong>${ccCar().name}</strong>${button('Choose car','cc-car','outline small')}</div><p class="helper">5 laps. Everyone races the same circuit and car.</p></div>`,button('Ready '+icon('check'),'close','primary'),'challenge-rules-dialog');}
function ccRenameDialog(){ccDialog('Give the dare a name.',`<div class="form-group"><label class="form-label" for="cc-name">Invitation name</label><input id="cc-name" class="form-input" maxlength="60" value="${escapeHtml(ccName())}"></div>`,button('Cancel','close','outline')+button('Keep this name','cc-rename-save','primary'));$('#cc-name').select();}
function ccReady(){const invitation=challengeLab.lastCreated;if(!invitation)return;const t=tracks[invitation.track],c=cars[invitation.car];challengeLab.copyText=`${invitation.name}\nCan you beat ${invitation.time}?\n${t.name} · ${c.name} · 5 laps\n${invitation.kind} · ${invitation.duration} · ${ccTries(invitation.tries)}\n[Local design prototype invitation; no live challenge link]`;ccDialog('Your move is out there.',`<p class="dialog-copy">Give them a time worth chasing.</p><article class="ready-invite">${scene(t.theme)}<p class="eyebrow">${invitation.kind==='Beat my time'?'HEAD TO HEAD':'BRING THE CREW'}</p><div class="ready-route">${route(invitation.track)}</div><h3>${escapeHtml(invitation.name)}</h3><div class="ready-time">${escapeHtml(invitation.time)}</div><p class="ready-track">${t.name}</p><p class="ready-rules">${c.name} · 5 laps<br>${invitation.duration} · ${ccTries(invitation.tries)}</p></article><p class="review-caption">Local invitation preview. No challenge was published or sent. Copying produces clearly marked prototype text.</p>`,button(icon('share')+'Copy invite text','cc-copy','outline')+button('View my challenges','created-challenges','primary'),'challenge-ready-dialog');}
function ccCreate(){if(!challengeLab.result)return;const r=challengeLab.result;challengeLab.lastCreated={name:ccName(),kind:challengeLab.draft.kind,duration:challengeLab.draft.duration,tries:challengeLab.draft.tries,track:r.track,car:r.car,time:r.time,raceId:r.raceId};state.createdChallenge={...challengeLab.lastCreated};challengeLab.awaitingResult=false;ccReady();}
function ccPrimary(){if(challengeLab.result){ccCreate();return;}state.track=challengeLab.draft.track;state.selectedCar=challengeLab.draft.car;challengeLab.awaitingResult=true;startRace('challenge-concept');}
function ccAfterRace(){if(!challengeLab.result)return;if(challengeLab.variant==='drive'){navigate('challenge-create');}else ccCreate();}

renderers['challenge-create']=challengeCreation;
headings['challenge-create']='CHALLENGE CREATION / A/B/C';
notes['challenge-create']=['Make the invitation the experience','Three alternatives replace the first-visit form with a different player action. Switching concepts keeps the same selected race and rules.',['A: a visual invitation with optional rule changes.','B: three complete race formats, with custom rules still available.','C: drive first, then invite from the ordinary race summary.','Use Menu / After a race to inspect both entry points. Completed track, car and result stay pinned.']];
const originalBeforeAction=actions.before;
actions.before=()=>state.screen==='challenge-create'?showModal('challenge-create'):originalBeforeAction();
actions['challenge-create']=()=>openChallengeConcept();
actions['cc-open']=()=>openChallengeConcept();
actions['cc-variant']=value=>{if(!(value in challengeVariants))return;challengeLab.variant=value;render();};
actions['cc-context']=value=>{challengeLab.context=value;challengeLab.result=value==='result'?ccResultFixture():null;if(challengeLab.result){challengeLab.draft.track=challengeLab.result.track;challengeLab.draft.car=challengeLab.result.car;}challengeLab.awaitingResult=false;render();};
actions['cc-kind']=value=>{if(!['Beat my time','Group challenge'].includes(value))return;challengeLab.draft.kind=value;challengeLab.draft.preset=null;render();};
actions['cc-preset']=value=>{const preset=showdownPresets[value];if(!preset)return;Object.assign(challengeLab.draft,{kind:preset.kind,duration:preset.duration,tries:preset.tries,preset:value});render();};
actions['cc-rules']=ccRules;
actions['cc-duration']=value=>{if(['24 hours','3 days','7 days'].includes(value))ccUpdateRule('duration',value,'cc-duration');};
actions['cc-tries']=value=>{if(['Unlimited','1','3','5'].includes(value))ccUpdateRule('tries',value,'cc-tries');};
actions['cc-rules-save']=()=>{if(!challengeLab.rulesDraft)return;Object.assign(challengeLab.draft,challengeLab.rulesDraft,{preset:null});closeModal();render();};
actions['cc-track']=ccTrackPicker;actions['cc-car']=ccCarPicker;actions['cc-setup']=ccSetup;
actions['cc-pick-track']=value=>{const i=Number(value);if(challengeLab.result||!Number.isInteger(i)||!tracks[i])return;challengeLab.draft.track=i;closeModal();render();};
actions['cc-pick-car']=value=>{const i=Number(value);if(challengeLab.result||!Number.isInteger(i)||!cars[i])return;challengeLab.draft.car=i;closeModal();render();};
actions['cc-rename']=ccRenameDialog;
actions['cc-rename-save']=()=>{challengeLab.draft.name=$('#cc-name').value.trim().slice(0,60);closeModal();render();};
actions['cc-primary']=ccPrimary;actions['cc-after-race']=ccAfterRace;
actions['cc-back']=()=>{challengeLab.awaitingResult=false;navigate(['results','analysis'].includes(challengeLab.source)?challengeLab.source:'challenges');};
actions['cc-copy']=async()=>{try{await navigator.clipboard.writeText(challengeLab.copyText);toast('Prototype invitation text copied.');}catch{ccDialog('Copy your invitation.',`<textarea class="challenge-share-text" aria-label="Prototype invitation text" readonly>${escapeHtml(challengeLab.copyText)}</textarea>`,button('Back to invitation','cc-ready','primary'));$('.challenge-share-text').select();}};
actions['cc-ready']=ccReady;
const previousInvitationAction=actions['view-invitation'];
actions['view-invitation']=()=>challengeLab.lastCreated?ccReady():previousInvitationAction();
const originalFinishRace=finishRace;
finishRace=function(){
 if(state.screen!=='driving')return;
 const finished={track:state.track,car:state.selectedCar,time:'01:23.407',raceId:'prototype-race-'+Date.now()};
 const isChallenge=state.raceOrigin==='challenge-concept'&&challengeLab.awaitingResult;
 state.completedSampleResult=finished;
 if(isChallenge){challengeLab.result={...finished};challengeLab.context='result';}
 originalFinishRace();
};
actions['finish-race']=finishRace;
const originalCreatedChallengePage=renderers.challenges;
renderers.challenges=()=>{
 const html=originalCreatedChallengePage();
 if(state.challengeTab==='created'&&state.createdChallenge?.time){
  return html.replace('<strong>01:23.407</strong>',`<strong>${escapeHtml(state.createdChallenge.time)}</strong>`);
 }
 return html;
};
const originalResetConcept=actions['reset-demo'];
actions['reset-demo']=()=>{challengeLab.variant='invitation';challengeLab.result=null;challengeLab.awaitingResult=false;challengeLab.lastCreated=null;challengeLab.draft={track:0,car:0,kind:'Beat my time',duration:'7 days',tries:'Unlimited',name:'',preset:'duel'};state.completedSampleResult=null;originalResetConcept();};
document.addEventListener('keydown',event=>{if(event.key==='Enter'&&state.modal==='challenge-concept'&&document.activeElement?.id==='cc-name'){event.preventDefault();actions['cc-rename-save']();}});
window.challengeConceptReady=true;
if(CHALLENGE_ENTRY||location.hash==='#challenge-create')openChallengeConcept('result');else renderChallengeReview();
