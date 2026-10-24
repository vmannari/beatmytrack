/* Second pass on the selected card concept. Review switches live outside the game. */
const earlierChallengeCards=showdownConcept;
const earlierChallengeName=ccName;
const earlierChallengeRules=ccRules;
const earlierChallengeReady=ccReady;
const earlierPresetAction=actions['cc-preset'];
const earlierRulesSave=actions['cc-rules-save'];
const earlierReviewRender=renderChallengeReview;
const earlierRuleUpdate=ccUpdateRule;
const refinedFormats={
 duel:{title:'Head to head',copy:'One rival. Your time to beat.',kind:'Beat my time',tries:'Unlimited',audience:'You + one rival'},
 weekend:{title:'Group race',copy:'Get the crew on the same grid.',kind:'Group challenge',tries:'Unlimited',audience:'Up to 20 drivers'},
 shots:{title:'Three tries',copy:'A little pressure. Make them count.',kind:'Group challenge',tries:'3',audience:'Up to 20 drivers'}
};
challengeLab.cardRevision='refined';
challengeLab.variant='showdown';
challengeVariants.showdown={label:'B · Challenge cards',description:'Choose your challenge. One clear choice, optional tweaks, then share.'};
function refinedCardsActive(){return challengeLab.variant==='showdown'&&challengeLab.cardRevision==='refined';}
function refinedFormatKey(draft=challengeLab.draft){return draft.kind==='Beat my time'?'duel':draft.tries==='3'?'shots':'weekend';}
function refinedFormatTitle(draft=challengeLab.draft){return refinedFormats[refinedFormatKey(draft)].title;}
ccName=function(){return refinedCardsActive()?(challengeLab.draft.name.trim()||`${refinedFormatTitle()} · ${ccTrack().name}`):earlierChallengeName();};
function rcGraphic(key){
 if(key==='duel')return `<span class="rc-duel-cars">${carImage(challengeLab.result?.car??challengeLab.draft.car)}<b>VS</b>${carImage(challengeLab.result?.car??challengeLab.draft.car)}</span>`;
 if(key==='weekend')return `<span class="rc-grid" aria-hidden="true">${Array.from({length:6},(_,i)=>`<span>${String(i+1).padStart(2,'0')}${icon('car')}</span>`).join('')}</span>`;
 return `<span class="rc-tries-graphic" aria-hidden="true"><span>01</span><span>02</span><span>03</span><i>BEST TIME WINS</i></span>`;
}
function refinedChallengeCards(){
 const result=challengeLab.result,d=challengeLab.draft,selected=refinedFormatKey();
 return `${ccTopline()}<div class="rc-heading"><div><p class="eyebrow">GIVE THEM SOMETHING TO CHASE</p><h1>CHOOSE YOUR <em>CHALLENGE.</em></h1></div><p>Pick the way you want to race.<br>We’ll take care of the invitation.</p></div>
 <section class="rc-race-ticket" aria-label="${result?'Your completed race':'Your selected race'}">${scene(ccTrack().theme)}<div class="rc-ticket-map">${route(ccTrackIndex())}</div><div class="rc-ticket-details"><p class="eyebrow">${result?'YOUR RACE. THEIR CHALLENGE.':'YOUR NEXT RACE'}</p><h2>${ccTrack().name}</h2><p>${ccCar().name} <span>·</span> 5 laps</p>${result?`<span class="creation-lock">${icon('shield')}Track & car fixed to this race</span>`:`<div class="rc-race-edit">${button('Circuit '+icon('chevron'),'cc-track','quiet small')}${button('Car '+icon('chevron'),'cc-car','quiet small')}</div>`}</div><div class="rc-ticket-target"><p>${result?'CAN THEY BEAT':'FIRST, SET THE TARGET'}</p><strong class="${result?'':'rc-no-time'}">${result?escapeHtml(result.time):'Your next drive'}</strong>${result?'<span>Your exact finish time</span>':'<span>Five laps. Then invite your rivals.</span>'}</div></section>
 <div class="rc-choice-label"><h2>HOW DO YOU WANT TO PLAY?</h2><span>Pick one · tweak it if you like</span></div><div class="showdown-options rc-options" role="group" aria-label="Challenge formats">${Object.entries(refinedFormats).map(([key,f])=>{const chosen=selected===key;const tries=chosen?d.tries:f.tries;return `<button class="showdown-card rc-card ${chosen?'active':''}" data-action="cc-preset" data-value="${key}" aria-pressed="${chosen}"><span class="showdown-check">${icon('check')}</span><div class="rc-card-art">${scene(ccTrack().theme)}${rcGraphic(key)}</div><div class="rc-card-copy"><h2>${f.title}</h2><p>${f.copy}</p><div class="rc-card-facts"><span>${f.audience}</span><span>${tries==='Unlimited'?'Unlimited tries':tries+' '+(tries==='1'?'try':'tries')+' each'}</span></div></div></button>`;}).join('')}</div>
 <div class="rc-tweak-row"><div><span class="rc-selected-title">${escapeHtml(d.name||refinedFormatTitle())}</span><p>${ccDuration()} <span>·</span> ${ccTries()} <span>·</span> Best time wins</p>${d.tries==='Unlimited'?'':`<small>Each start uses a try, including restarts.</small>`}</div>${button('Tweak the rules '+icon('chevron'),'cc-rules','quiet small')}</div>
 <footer class="creation-footer rc-footer"><p class="creation-footer-copy">${result?'<strong>Your time is set. The next move is theirs.</strong>Create the challenge, then share the invitation.':'<strong>A good challenge starts with your drive.</strong>Set a time first. Your card and rules will be waiting.'}</p>${button((result?'Create & share':'Race to set a time')+' '+icon('arrow'),'cc-primary','primary')}</footer>`;
}
showdownConcept=function(){return refinedCardsActive()?refinedChallengeCards():earlierChallengeCards();};
actions['cc-preset']=value=>{
 if(!refinedCardsActive()){earlierPresetAction(value);return;}
 const format=refinedFormats[value];if(!format)return;
 Object.assign(challengeLab.draft,{kind:format.kind,tries:format.tries,preset:value});render();
 $(`.rc-card[data-value="${value}"]`)?.focus({preventScroll:true});
};
function rcRuleSummary(){const d=challengeLab.rulesDraft;return `${ccDuration(d.duration)} · ${ccTries(d.tries)}. <strong>Best time wins.</strong>${d.tries==='Unlimited'?'':`<span class="rc-try-note">Each start uses a try, including restarts.</span>`}`;}
ccRules=function(){
 if(!refinedCardsActive()){earlierChallengeRules();return;}
 challengeLab.rulesDraft={duration:challengeLab.draft.duration,tries:challengeLab.draft.tries};
 ccDialog('Make it your challenge.',`<p class="dialog-copy">A quick tweak, if you want one.</p><div class="rule-choice-group"><p>Time to take the challenge</p>${ccChipGroup([['24 hours','24 hours'],['3 days','3 days'],['7 days','7 days']],challengeLab.rulesDraft.duration,'cc-duration','Challenge duration')}</div><div class="rule-choice-group"><p>Tries per driver</p>${ccChipGroup([['Unlimited','Unlimited'],['1','1'],['3','3'],['5','5']],challengeLab.rulesDraft.tries,'cc-tries','Tries per driver')}</div><p class="rule-summary" id="cc-rule-summary">${rcRuleSummary()}</p><details class="rc-optional-name"><summary>Add a personal title <span>optional</span></summary><label class="form-label" for="rc-name">Challenge title</label><input class="form-input" id="rc-name" maxlength="60" value="${escapeHtml(challengeLab.draft.name)}" placeholder="${escapeHtml(refinedFormatTitle()+' · '+ccTrack().name)}"></details>`,button('Cancel','close','outline')+button('Keep these rules '+icon('check'),'cc-rules-save','primary'),'challenge-rules-dialog rc-rules-dialog');
};
ccUpdateRule=function(key,value,action){earlierRuleUpdate(key,value,action);if(refinedCardsActive()&&$('#cc-rule-summary'))$('#cc-rule-summary').innerHTML=rcRuleSummary();};
actions['cc-rules']=()=>ccRules();
actions['cc-rules-save']=()=>{if(refinedCardsActive()&&$('#rc-name')){if(!challengeLab.rulesDraft)return;challengeLab.draft.name=$('#rc-name').value.trim().slice(0,60);}earlierRulesSave();};
for(const [action,title] of [['cc-track','Choose your circuit.'],['cc-car','Choose your car.']]){const previous=actions[action];actions[action]=()=>{previous();if(refinedCardsActive()&&$('#concept-dialog-title'))$('#concept-dialog-title').textContent=title;};}
ccReady=function(){
 if(!refinedCardsActive()){earlierChallengeReady();return;}
 const invitation=challengeLab.lastCreated;if(!invitation)return;
 const t=tracks[invitation.track],c=cars[invitation.car];
 challengeLab.copyText=`${invitation.name}\nCan you beat ${invitation.time}?\n${t.name} · ${c.name} · 5 laps\n${invitation.kind} · ${invitation.duration} · ${ccTries(invitation.tries)}${invitation.tries==='Unlimited'?'':'\nEach start uses a try, including restarts.'}\n[Local design prototype invitation; no live challenge link]`;
 ccDialog('Your challenge is ready.',`<p class="dialog-copy">Send the invitation. Let the chase begin.</p><article class="ready-invite rc-ready-invite">${scene(t.theme)}<p class="eyebrow">${invitation.kind==='Beat my time'?'YOU + ONE RIVAL':'UP TO 20 DRIVERS'}</p><div class="ready-route">${route(invitation.track)}</div><h3>${escapeHtml(invitation.name)}</h3><p class="rc-ready-kicker">CAN YOU BEAT</p><div class="ready-time">${escapeHtml(invitation.time)}</div><p class="ready-track">${t.name}</p><p class="ready-rules">${c.name} · 5 laps<br>${invitation.duration} · ${ccTries(invitation.tries)}</p></article><p class="review-caption">Local preview only. Copying produces marked prototype text; no challenge is published or sent.</p>`,button('View my challenges','created-challenges','outline')+button(icon('share')+'Copy invite','cc-copy','primary'),'challenge-ready-dialog rc-ready-dialog');
};
actions['cc-ready']=()=>ccReady();
renderChallengeReview=function(){
 earlierReviewRender();
 if(state.screen==='challenge-create'){
  const old=challengeLab.cardRevision==='earlier';
  const host=$('#challenge-review');
  if(CHALLENGE_FOCUS)host.classList.add('rc-focused-review');
  if(challengeLab.variant==='showdown'){
   $('.concept-review-label',host).textContent='CHALLENGE CARDS / DESIGN REFINEMENT';
   const controls=document.createElement('div');controls.className='rc-review-revisions';
   controls.innerHTML=`<div role="group" aria-label="Card design revision"><button data-action="rc-revision" data-value="refined" aria-pressed="${!old}">Refined cards</button><button data-action="rc-revision" data-value="earlier" aria-pressed="${old}">Earlier cards</button></div><span>${old?'Previous direction: Showdown.':'Working name: Choose your challenge. Duration stays put when you switch cards.'}</span>`;
   $('.concept-review',host).append(controls);
   $('#screen-label').textContent=old?'CHALLENGE CARDS / EARLIER':'CHOOSE YOUR CHALLENGE / REFINED';
  }
  if(CHALLENGE_FOCUS){
   const expanded=!!challengeLab.compareExpanded;
   host.innerHTML=`<section class="concept-review rc-review-compact"><div class="rc-lab-line"><span class="concept-review-label">CHALLENGE CARDS / REFINEMENT</span><div class="rc-lab-revisions" role="group" aria-label="Card design revision"><button data-action="rc-revision" data-value="refined" aria-pressed="${!old}">Refined cards</button><button data-action="rc-revision" data-value="earlier" aria-pressed="${old}">Earlier cards</button></div><div class="concept-context"><span>TRY FROM</span><button data-action="cc-context" data-value="menu" aria-pressed="${!challengeLab.result}">Menu</button><button data-action="cc-context" data-value="result" aria-pressed="${!!challengeLab.result}">After a race</button></div><button class="rc-more-concepts" data-action="rc-compare" aria-expanded="${expanded}">${expanded?'Hide':'Other'} concepts</button></div>${expanded?`<div class="concept-variants" role="group" aria-label="Challenge concept">${Object.entries(challengeVariants).map(([key,value])=>`<button class="concept-switch" data-action="cc-variant" data-value="${key}" aria-pressed="${challengeLab.variant===key}">${value.label}</button>`).join('')}</div>`:''}<p class="rc-lab-caption">${challengeLab.variant==='showdown'?(old?'Previous direction: Showdown.':'Working name: Choose your challenge. Switch cards without changing your chosen duration.'):challengeVariants[challengeLab.variant].description}</p></section>`;
  }
 }
 if(state.screen==='results'&&challengeLab.awaitingResult&&refinedCardsActive()){
  const next=$('[data-action="cc-after-race"]');if(next)next.innerHTML='Create & share '+icon('arrow');
 }
};
actions['rc-revision']=value=>{if(!['earlier','refined'].includes(value))return;challengeLab.cardRevision=value;render();};
actions['rc-compare']=()=>{challengeLab.compareExpanded=!challengeLab.compareExpanded;render();};
const cardsResetAction=actions['reset-demo'];
actions['reset-demo']=()=>{cardsResetAction();challengeLab.variant='showdown';challengeLab.cardRevision='refined';render();};
notes['challenge-create']=['Choose your challenge','The selected card direction now starts with the actual race, then one inviting choice.',['Head to head: you and one rival. Group race: up to 20 drivers. Three tries: a group race with a little pressure.','Switching cards changes the format and tries. Your chosen duration, track, car and title stay put.','Rules and a personal title are optional. Finite starts include restarts.','After a race, the exact finish stays pinned. Create & share leads to an invitation you can copy.','Earlier cards and the other concepts remain available in the review controls.']];
$('#jump option[value="challenge-create"]').textContent='Create challenge · Cards';
render();
