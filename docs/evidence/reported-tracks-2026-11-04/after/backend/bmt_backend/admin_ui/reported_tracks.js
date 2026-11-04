'use strict';
let reportedTrackView=null;
function reportedHref(id,params,changes={}){
 const query=new URLSearchParams(params);for(const [name,value] of Object.entries(changes))value==null?query.delete(name):query.set(name,String(value));
 return '#reported-tracks'+(id?'/'+encodeURIComponent(id):'')+(query.size?'?'+query:'');
}
function reportedPager(data,id,params){
 const href=offset=>reportedHref(id,params,{offset});
 return `<div class="console-pager"><span>${data.items.length?data.offset+1:0}–${data.offset+data.items.length}</span><a class="btn ${data.offset?'':'stc-disabled'}" ${data.offset?'':'aria-disabled="true" tabindex="-1"'} href="${href(Math.max(0,data.offset-data.limit))}">Previous</a><a class="btn ${data.has_more?'':'stc-disabled'}" ${data.has_more?'':'aria-disabled="true" tabindex="-1"'} href="${href(data.offset+data.limit)}">Next</a></div>`;
}
async function reportedTracks(id,params){
 const ticket=generation,query=new URLSearchParams();
 for(const field of id?['offset','limit']:['q','visibility','sort','offset','limit'])if(params.has(field))query.set(field,params.get(field));
 const data=await api('reported-tracks'+(id?'/'+encodeURIComponent(id):'')+'?'+query);role=data.role;
 if(ticket===generation)reportedTrackView=id?{data,params:new URLSearchParams(params)}:null;
 if(!id){
  const rows=data.items.map(t=>`<tr><td><a class="stc-track-identity" href="${reportedHref(t.track_id,params,{offset:null})}">${catalogueShape(t.preview,true)}<span><strong>${esc(t.name)}</strong><small>${esc(t.creator_name)}</small></span></a></td><td><strong>${esc(t.report_count)}</strong></td><td>${esc(t.reporters)}</td><td>${esc(t.unresolved)}</td><td>${esc(date(t.last_reported_at))}</td><td>${status(t.deleted?'Deleted':t.hidden?'Hidden':'Visible')}</td><td><a class="btn" href="${reportedHref(t.track_id,params,{offset:null})}">Review reports</a></td></tr>`).join('');
  return intro('Reported tracks','Review player reports and decide which tracks need action.','MODERATION')+card('Report queue',`<form id="reported-track-filters" class="stc-filters"><label class="stc-search">Find a track<input name="q" maxlength="100" placeholder="Track name, creator or track ID" value="${esc(params.get('q')||'')}"></label>${catalogueSelect('visibility','Tracks',[['active','Not deleted'],['deleted','Deleted'],['all','All reported tracks']],params.get('visibility')||'active')}${catalogueSelect('sort','Sort by',[['reports','Most reported'],['recent','Latest report']],params.get('sort')||'reports')}<button class="btn btn-primary">Apply</button><a class="btn" href="#reported-tracks">Reset</a></form><p class="console-note">${esc(data.scope)}. Reports are reviewed by a person; volume alone does not remove a track.</p><div class="console-table"><table><thead><tr><th>Track / creator</th><th>Reports</th><th>Reporters</th><th>Unresolved</th><th>Latest report</th><th>Visibility</th><th>Action</th></tr></thead><tbody>${rows}</tbody></table>${rows?'':'<div class="stc-empty"><h3>No reported tracks in this view</h3><p>Try another search or include deleted tracks.</p></div>'}</div>${reportedPager(data,'',params)}`);
 }
 const t=data.track,rows=data.items.map(r=>`<tr><td>${esc(date(r.reported_at))}<small>${esc(r.reporter)}</small></td><td><strong>${esc(r.reason.replaceAll('_',' '))}</strong><p class="case-note">${esc(r.text)}</p>${r.version_id?link('tracks',r.version_id,'Reported version'):''}</td><td>${status(r.status)}</td><td>${link('cases',r.case_id,'Open case')}</td></tr>`).join('');
 return intro(t.name,'Reports across all published versions.','REPORTED TRACK')+`<div class="console-actions"><a class="btn" href="${reportedHref('',params,{offset:null})}">Back to reported tracks</a>${t.version_id?link('tracks',t.version_id,'Inspect track'):''}${t.deleted?status('Deleted'):role==='owner'?'<button class="btn btn-primary" id="delete-reported-track">Delete track</button>':'<span class="console-note">Owner access required to delete tracks.</span>'}</div><div class="stc-summary">${catalogueStat('Reports',t.report_count,'All retained player reports')}${catalogueStat('Reporters',t.reporters,'Distinct retained accounts')}${catalogueStat('Unresolved',t.unresolved,'Open, investigating or appealed')}</div>`+(t.deleted?'<p class="console-note" role="status">This track has been deleted from public access. Reports and historical race records are retained.</p>':'')+card('Player reports',`<div class="console-table"><table><thead><tr><th>Reported / player</th><th>Reason / details</th><th>Case state</th><th>Investigation</th></tr></thead><tbody>${rows}</tbody></table></div>${reportedPager(data,id,params)}`);
}
function wireReportedTracks(){
 const form=$('#reported-track-filters');if(form)form.onsubmit=event=>{event.preventDefault();const query=new URLSearchParams();for(const [name,value] of new FormData(form))if(value)query.set(name,value);location.hash=reportedHref('',query);};
 const button=$('#delete-reported-track');if(!button||!reportedTrackView||role!=='owner')return;
 const view=reportedTrackView;
 button.onclick=()=>{
  const {track,items}=view.data,report=items[0];if(!report)return;
  modal(`<h2>Delete ${esc(track.name)}?</h2><p>This removes every version from public racing, discovery and shared links. Reports and past race records are retained. This view cannot restore the track.</p><form id="reported-track-delete"><label>Recorded reason<textarea name="reason" minlength="8" maxlength="500" required></textarea></label><label><input name="acknowledged" type="checkbox" required> I understand this removes the track from public access.</label><p class="console-error" id="reported-delete-error" role="alert" hidden></p><div class="console-actions"><button class="btn" type="button" data-close>Cancel</button><button class="btn btn-primary" type="submit">Confirm deletion</button></div></form>`);
  const token=dialogToken();let command=crypto.randomUUID(),pending=null;
  $('#reported-track-delete').onsubmit=async event=>{
   event.preventDefault();if(!dialogIsCurrent(token))return;
   const submit=event.target.querySelector('[type=submit]');submit.disabled=true;
   // Retain the exact command/body after a lost response; edits need a new command.
   const body=pending||(pending={command_id:command,case_id:report.case_id,expected_revision:report.revision,expected_state:track.state_token,reason:event.target.elements.reason.value.trim(),acknowledged:true});
   event.target.elements.reason.disabled=true;event.target.elements.acknowledged.disabled=true;
   try{await api('reported-tracks/'+track.track_id+'/delete',body);if(!dialogIsCurrent(token))return;$('#dialog').close();await render();}
   catch(error){if(dialogIsCurrent(token)){const notice=$('#reported-delete-error');notice.hidden=false;notice.textContent=error.message==='STATE_CHANGED_REFRESH_REQUIRED'?'The track or report changed. Close this dialog and refresh before deleting.':error.message;submit.disabled=error.status===409;if(error.status===422){pending=null;command=crypto.randomUUID();event.target.elements.reason.disabled=false;event.target.elements.acknowledged.disabled=false;}}}
  };
 };
}
