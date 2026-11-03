import { t as tr, message, errorText } from '../shared/i18n.mjs';
import './theme.css';
import './workstation.css';
import { createIcons, icons } from 'lucide';
import demoFixture from '../assets/demo.json';
import { newTrade, parseBackup, tradeSchema, net, compliant, execution, groups, dateKey, matchesSearch, periodRange, instantFromWallTime } from '../shared/core.mjs';
import { esc, glyph, command, toggle, imageGallery, workspaceView, drawCharts, navigation } from './views.js';
import { tradeEditor, setupEditor, reviewEditor, reviewSnapshot, detailView, processPreview } from './editors.js';
import { openImage } from './image-review.js';
import { accountFor, selectedAccount, scopedTrades, withWorkspace, legacyAccountID } from '../shared/workspace-state.mjs';
import { filterRows, workspaceActions } from './workspace-actions.js';
import { motionAllowed } from './precision-chart.js';

const api=window.journal, $=selector=>document.querySelector(selector), editor=$('#editor');
const emptyFilters=()=>({search:'',instrument:'',session:'',compliance:'',from:'',to:''});
const state={view:'Dashboard',filters:emptyFilters(),facets:{},advanced:false,period:'ALL TIME',curveMode:'$',analysis:'Setup',groupMetric:'Average R',month:new Date(),selectedDay:'',showR:false,imageCategory:'',tradeSort:'Newest',demo:false,collapsed:false,researchFirst:'Setup',researchSecond:'Session',scatterX:'process',scatterY:'r',horizon:100,shuffle:false};
let data,charts=[],draft,draftKind,draftShots=[],busy=false;
const decorate=()=>createIcons({icons});
function notify(message,error=false){$('#toast').textContent=tr(message);$('#toast').classList.toggle('warning',error);clearTimeout(notify.timer);notify.timer=setTimeout(()=>$('#toast').textContent='',error?10000:4000);}
const report=error=>notify(errorText(error),true);
const pages = new Map();
const actions = workspaceActions({ data: () => data, state, render, persist, showEditor, editor, notify, report });
function navigate(view, query) {
  if (view === state.view && query === undefined) return;
  pages.set(state.view, { filters: state.filters, facets: state.facets, advanced: state.advanced, scroll: window.scrollY });
  const next = pages.get(view);
  state.view = view;
  state.filters = next?.filters ?? emptyFilters();
  state.facets = next?.facets ?? {};
  state.advanced = next?.advanced ?? false;
  if (query !== undefined) {
    state.filters = { ...emptyFilters(), search: query };
    state.facets = {};
  }
  render();
}
function accountData(account = selectedAccount(data)) {
  return { ...data, trades: scopedTrades(data), preferences: { ...data.preferences, currency: account.currency, accountSize: account.startingBalance } };
}
function resetWorkspaceUI() {
  pages.clear();
  state.filters = emptyFilters();
  state.facets = {};
  state.advanced = false;
  state.equityPresented = false;
  state.selectedTrade = '';
  state.loadedPreset = state.comparePreset = state.cohort = '';
  state.planDraft = state.csvSource = state.csvMapping = state.csvPreview = null;
  actions.invalidateSimulation();
}
function filtered(scoped) {
  const zone = data.preferences.timezone;
  if (state.view === 'Dashboard') {
    if (state.period === 'ALL TIME') return scoped;
    const range = periodRange(Date.now(), { TODAY:'Daily', 'THIS WEEK':'Weekly', 'THIS MONTH':'Monthly' }[state.period], zone);
    return scoped.filter(t => { const day = dateKey(t.date, zone); return day >= range.from && day <= range.to; });
  }
  return ['Trades', 'Analytics', 'Research', 'Setup Analysis', 'Statistics'].includes(state.view)
    ? filterRows(scoped, state.filters, state.facets, zone) : scoped;
}
function render() {
  clearTimeout(notify.searchTimer);
  charts.forEach(chart => chart?.destroy());
  const p = data.preferences, pageKey = state.view + ':' + state.demo;
  const newPage = render.pageKey !== pageKey, modeChanged = render.curveMode !== state.curveMode;
  const scroll = newPage ? pages.get(state.view)?.scroll ?? 0 : window.scrollY;
  const active = document.activeElement;
  const activeName = active?.closest('main') && active.name;
  const activeId = active?.closest('main') && active.id;
  document.documentElement.classList.toggle('light', p.theme === 'Light' || p.theme === 'System' && matchMedia('(prefers-color-scheme: light)').matches);
  document.documentElement.classList.toggle('no-motion', !motionAllowed(p));
  const scoped = accountData(), rows = filtered(scoped.trades);
  $('#app').innerHTML = workspaceView(scoped, state, rows, data, actions.applyPreset);
  decorate();
  charts = drawCharts(scoped, state, rows);
  if (newPage) $('main').classList.add('page-enter');
  if (modeChanged && !newPage) $('#equity')?.closest('.chart').classList.add('plot-enter');
  render.pageKey = pageKey;
  render.curveMode = state.curveMode;
  window.scrollTo(0, scroll);
  if (!newPage && !editor.open) {
    const input = activeId ? document.getElementById(activeId) : activeName ? document.querySelector('main [name="' + CSS.escape(activeName) + '"]') : null;
    if (input && !input.disabled) input.focus({ preventScroll: true });
  }
  if (state.view === 'Settings') api.dataPath().then(path => { if ($('#data-path')) $('#data-path').textContent = path; }).catch(report);
}
async function persist(next) {
  const valid = withWorkspace(parseBackup({ ...next, started: true }));
  data = state.demo ? valid : await api.save(valid);
  actions.invalidateSimulation();
  render();
}
function showEditor(html,kind){draftKind=kind;editor.innerHTML=html;editor.style.width=kind==='detail'?'min(1000px,calc(100vw - 40px))':'';if(!editor.open)editor.showModal();decorate();}
function editTrade(id) {
  const record = data.trades.find(t => t.id === id);
  const accountID = record ? accountFor(data, record.id) : data.workspace.selectedAccountID;
  const account = data.workspace.accounts.find(a => a.id === accountID);
  const scoped = accountData(account);
  draft = structuredClone(record || { ...newTrade(), riskPercent: data.preferences.defaultRiskPercent, riskDollars: account.startingBalance * data.preferences.defaultRiskPercent / 100 });
  draftShots = structuredClone(data.screenshots.filter(s => s.tradeID === id).map(s => s.screenshot));
  showEditor(tradeEditor(draft, scoped, draftShots, !record, accountID), 'trade');
  updateTradePreview();
}
function showTrade(id) {
  draft = structuredClone(data.trades.find(t => t.id === id));
  if (!draft) return;
  draftShots = [];
  const account = data.workspace.accounts.find(a => a.id === accountFor(data, id));
  showEditor(detailView(draft, accountData(account)), 'detail');
}
document.addEventListener('edge:trade', event => showTrade(event.detail));
document.addEventListener('edge:scatter', event => { state.scatterID = event.detail; render(); });
const blankSetup=name=>({id:crypto.randomUUID(),playbookID:crypto.randomUUID(),name,summary:'',conditions:'',entry:'',invalidation:'',target:'',risk:'',images:[]});
function editSetup(id){draft=structuredClone(data.setups.find(s=>s.id===id)||blankSetup(''));draftShots=structuredClone(draft.images);showEditor(setupEditor(draft,draftShots),'setup');}
function editReview(id){draft=structuredClone(data.reviews.find(r=>r.id===id)||{id:crypto.randomUUID(),period:'Weekly',date:Date.now(),worked:'',didNot:'',repeatNext:'',stop:'',adjustment:''});draftShots=[];showEditor(reviewEditor(draft,data),'review');}
function confirmAction(message){const dialog=$('#confirm');dialog.returnValue='cancel';dialog.innerHTML=`<p>${esc(tr(message))}</p><form method="dialog" class="footer"><button value="cancel" autofocus>Vazgeç</button><button value="confirm" class="danger">Sil</button></form>`;dialog.showModal();return new Promise(resolve=>dialog.addEventListener('close',()=>resolve(dialog.returnValue==='confirm'),{once:true}));}
function gatherTrade(form,validate=true){
  const result=structuredClone(draft),values=new FormData(form),lists=['contextTimeframes','liquidityTaken','confirmations','brokenRules','emotional.emotions','ssmt.markets'],optional=['entryPrice','stopLoss','takeProfit','exitPrice','positionSize','riskDollars','riskPercent','rMultiple','crt.high','crt.low'];
  for(const input of form.querySelectorAll('[name]')){
    const name=input.name;if(lists.includes(name)||['attachment-category','record-exit','workspace-accountID'].includes(name))continue;
    let value=input.type==='checkbox'?input.checked:input.value;
    if(input.type==='number'||input.type==='range')value=value===''&&optional.includes(name)?undefined:Number(value);
    if(['date','exitDate'].includes(name))value=value?instantFromWallTime(value,data.preferences.timezone):undefined;
    if(name==='tags')value=value.split(',').map(v=>v.trim()).filter(Boolean);
    const[head,tail]=name.split('.');if(tail)result[head][tail]=value;else result[head]=value;
  }
  for(const name of lists){const[head,tail]=name.split('.');if(tail)result[head][tail]=values.getAll(name);else result[head]=values.getAll(name);}
  if(!values.has('record-exit'))delete result.exitDate;
  const setup=data.setups.find(s=>s.id===result.setupID);if(setup)result.setupID=setup.id;else delete result.setupID;result.setupName=setup?.name||'Unassigned';
  return validate?tradeSchema.parse(result):result;
}
function updateTradePreview(){
  if(draftKind!=='trade'||!$('#edit-form'))return;const t=gatherTrade($('#edit-form'),false);$('#process-preview').innerHTML=processPreview(t);$('#overall-score').textContent=`${execution(t).toFixed(0)} / 100`;
  const planned=t.entryPrice!=null&&t.stopLoss!=null&&t.takeProfit!=null&&t.entryPrice!==t.stopLoss?Math.abs(t.takeProfit-t.entryPrice)/Math.abs(t.entryPrice-t.stopLoss):null;
  $('#price-preview').textContent=`Net K/Z ${net(t).toLocaleString('tr-TR')} / Planlanan risk/getiri ${planned==null?tr('Not recorded'):planned.toLocaleString('tr-TR')}`;
  $('#broken-rule-fields').hidden=t.followsPlan&&!t.brokenRules.length;$('#exit-time-field').hidden=!$('#edit-form [name="record-exit"]').checked;
  for(const element of editor.querySelectorAll('[data-conditional]')){const[head,key]=element.dataset.conditional.split('.');element.hidden=key==='model'?t[head][key]==='None':!t[head][key];}
}
function refreshShots(){$('#draft-shots').innerHTML=imageGallery(draftShots,true);decorate();}
async function addImages(files){
  if(!['trade','setup'].includes(draftKind))return;
  const images=files?await api.dropImages(await Promise.all([...files].map(async f=>({name:f.name,bytes:new Uint8Array(await f.arrayBuffer())})))):await api.pickImages();
  const category=editor.querySelector('[name="attachment-category"]').value;images.forEach(s=>s.category=category);draftShots.push(...images);refreshShots();
}
function showImage(id){const shot=[...draftShots,...data.screenshots.map(s=>s.screenshot),...data.setups.flatMap(s=>s.images)].find(s=>s.id===id);if(!shot)return;openImage(shot,async updated=>{
  if(['trade','setup'].includes(draftKind)&&editor.open&&draftShots.some(s=>s.id===id)){draftShots=draftShots.map(s=>s.id===id?updated:s);refreshShots();return;}
  const next=structuredClone(data);next.screenshots=next.screenshots.map(s=>s.screenshot.id===id?{...s,screenshot:updated}:s);next.setups.forEach(s=>s.images=s.images.map(image=>image.id===id?updated:image));await persist(next);if(editor.open&&draftKind==='detail')showTrade(draft.id);
},decorate,report);}
function searchCommand(){
  const dialog=document.createElement('dialog');dialog.className='command-palette';dialog.innerHTML=`<header><input type="search" aria-label="Çalışma alanında ara" placeholder="İşlem veya sayfa ara…">${command('dismiss','Close')}</header><div class="body"></div>`;document.body.append(dialog);const input=dialog.querySelector('input'),body=dialog.querySelector('.body');
  function results(){const q=input.value;body.innerHTML=navigation.filter(([name])=>!q||tr(name).toLocaleLowerCase('tr-TR').includes(q.toLocaleLowerCase('tr-TR'))||name.toLowerCase().includes(q.toLowerCase())).map(([name,icon])=>`<button data-destination="${name}">${glyph(icon)}${tr(name)}</button>`).join('')+data.trades.filter(t=>matchesSearch(t,q)).sort((a,b)=>b.date-a.date).slice(0,30).map(t=>`<button data-result="${t.id}">${esc(t.instrument)} / ${esc(t.setupName)}<small>${dateKey(t.date,data.preferences.timezone)}</small></button>`).join('');decorate();}
  const footer=document.createElement('footer');footer.className='footer';footer.innerHTML=command('search-all','Show all matching trades');dialog.append(footer);
  input.oninput=results;dialog.onclick=e=>{const b=e.target.closest('button');if(!b)return;dialog.close();if(b.dataset.action==='search-all'){navigate('Trades',input.value);}else if(b.dataset.destination==='New Trade')editTrade();else if(b.dataset.destination){navigate(b.dataset.destination);}else if(b.dataset.result)showTrade(b.dataset.result);};dialog.onclose=()=>dialog.remove();results();dialog.showModal();input.focus();
}
function dayInstant(day){
  return instantFromWallTime(day+'T12:00',data.preferences.timezone);
}
async function deleteRecord(kind,id){if(!await confirmAction(`Delete this ${kind}? This cannot be undone.`))return;const next=structuredClone(data),key={trade:'trades',setup:'setups',review:'reviews'}[kind];next[key]=next[key].filter(item=>item.id!==id);if(kind==='trade'){next.screenshots=next.screenshots.filter(s=>s.tradeID!==id);delete next.workspace.assignments[id.toLowerCase()];delete next.workspace.supplements[id.toLowerCase()];state.selectedTrade='';}if(kind==='setup')next.trades.forEach(t=>{if(t.setupID===id){delete t.setupID;t.setupName='Unassigned';}});await persist(next);if(editor.open)editor.close();notify('Deleted.');}
document.addEventListener('click',async event=>{
  const target=event.target.closest('button,.drop-zone');if(!target||busy||target.closest('.image-dialog,.command-palette,#confirm'))return;
  try{
    if(target.dataset.view){navigate(target.dataset.view);return;}
    if(target.dataset.trade){if(state.view==='Trades'){state.selectedTrade=target.dataset.trade;render();}else showTrade(target.dataset.trade);return;}if(target.dataset.shot){showImage(target.dataset.shot);return;}
    for(const[key,stateKey]of[['period','period'],['curveMode','curveMode'],['day','selectedDay']])if(target.dataset[key]){state[stateKey]=target.dataset[key];render();return;}
    const action=target.dataset.action;
    if (!action && !target.dataset.cohort && !target.classList.contains('drop-zone')) return;
    if(action==='open-source'){showTrade(target.dataset.id);return;}
    busy=true;
    if(await actions.click(action,target))return;
    if(action==='export-pdf'){if(await api.exportPDF())notify('PDF kaydedildi.');return;}
    if(target.classList.contains('drop-zone')||action==='add-images'){await addImages();return;}
    if(action==='new-trade')editTrade();else if(action==='edit-trade')editTrade(draft.id);else if(action==='close-editor')editor.close();
    else if(action==='new-setup'||action==='edit-setup')editSetup(target.dataset.id);else if(action==='new-review'||action==='edit-review')editReview(target.dataset.id);
    else if(action==='delete-setup'||action==='delete-review')await deleteRecord(action.slice(7),target.dataset.id);else if(action==='delete-record')await deleteRecord('trade',draft.id);
    else if(action==='collapse-sidebar'){state.collapsed=!state.collapsed;render();}else if(action==='search-command')searchCommand();
    else if(action==='toggle-filters'){state.advanced=!state.advanced;render();}else if(action==='reset-filters'){state.filters=emptyFilters();state.facets={};render();}
    else if(action?.startsWith('month-')){state.month=action==='month-today'?new Date():new Date(state.month.getFullYear(),state.month.getMonth()+(action==='month-next'?1:-1),1);state.selectedDay='';render();}
    else if(action==='demo'){state.demo=true;data=withWorkspace(structuredClone(demoFixture));resetWorkspaceUI();render();}else if(action==='exit-demo'){data=withWorkspace(await api.load());state.demo=false;resetWorkspaceUI();render();}
    else if(action==='remove-shot'){draftShots=draftShots.filter(s=>s.id!==target.dataset.id);refreshShots();}
    else if(action==='calculate-r'){const t=gatherTrade($('#edit-form'),false);if(!(t.riskDollars>0))throw new Error('Enter positive dollar risk to calculate net R.');editor.querySelector('[name="rMultiple"]').value=net(t)/t.riskDollars;updateTradePreview();}
    else if(action==='add-broken-rule'||action==='add-market'){
      const rule=action==='add-broken-rule',input=$(rule?'#custom-broken-rule':'#custom-market'),value=input.value.trim(),name=rule?'brokenRules':'ssmt.markets';if(!value)return;const list=$(rule?'#broken-rule-fields .checklist':'#market-checklist .checklist'),existing=[...list.querySelectorAll('input')].find(i=>i.value===value);if(existing)existing.checked=true;else list.insertAdjacentHTML('beforeend',toggle(name,value,true,`value="${esc(value)}"`));if(rule)editor.querySelector('[name="followsPlan"]').checked=false;input.value='';updateTradePreview();
    }else if(action==='quick-setup'){
      const name=$('#quick-setup').value.trim();if(!name)return;const t=gatherTrade($('#edit-form'),false),s=blankSetup(name);await persist({...data,setups:[...data.setups,s]});draft={...t,setupID:s.id,setupName:s.name};showEditor(tradeEditor(draft,accountData(),draftShots,true,data.workspace.selectedAccountID),'trade');updateTradePreview();
    }else if(action==='add-session'){
      const input=$('#custom-session'),name=input.value.trim();if(!name)return;const hidden=$('#preferences [name=sessions]'),names=hidden.value.split(',').map(v=>v.trim()).filter(Boolean);if(name.includes(','))throw new Error('Session names cannot contain commas.');if(names.includes(name))return;names.push(name);hidden.value=names.join(', ');$('#session-fields').insertAdjacentHTML('beforeend',`<div class="session-row"><span>${esc(name)}</span><input name="session:${esc(name)}" aria-label="${esc(name)} seans saatleri">${command('remove-session','', 'circle-minus',`class="icon" title="Seansı kaldır" aria-label="Seansı kaldır" data-id="${esc(name)}"`)}</div>`);input.value='';decorate();
    }else if(action==='remove-session'){const hidden=$('#preferences [name=sessions]');hidden.value=hidden.value.split(',').map(v=>v.trim()).filter(v=>v!==target.dataset.id).join(', ');target.closest('.session-row').remove();}
    else if(action==='remove-rule')await persist({...data,rules:data.rules.filter(r=>r.id!==target.dataset.id)});
    else if(['export-backup','export-legacy','import-backup','export-csv','import-csv'].includes(action)){busy=true;const result=await api[{'export-backup':'exportBackup','export-legacy':'exportLegacyBackup','import-backup':'importBackup','export-csv':'exportCSV','import-csv':'importCSV'}[action]](data,state.demo);if(result&&action.startsWith('import')){data=withWorkspace(result);resetWorkspaceUI();render();notify('Import complete.');}else if(result)notify('Export complete.');}
  }catch(error){report(error);}finally{busy=false;}
});
document.addEventListener('change',async event=>{
  const input=event.target;if(input.closest('.image-dialog') || busy || !data)return;
  if (input.id === 'account-picker' || input.hasAttribute('data-account-picker')) busy = true;
  try { if (await actions.change(input)) return; }
  catch (error) { report(error); return; }
  finally { busy = false; }
  if (input.name === 'workspace-accountID') {
    const account = data.workspace.accounts.find(a => a.id === input.value);
    for (const [name, label] of [['grossPnL','Brüt K/Z'],['riskDollars','Risk']]) {
      const field = editor.querySelector('[name="' + name + '"]');
      field.setAttribute('aria-label', label + ' ' + account.currency);
      field.previousElementSibling.textContent = label + ' ' + account.currency;
    }
  }
  if(input.dataset.filter){state.filters[input.dataset.filter]=input.value;render();}if(input.dataset.facet){state.facets[input.dataset.facet]=input.value;render();}
  const keys={'dimension':'analysis','group-metric':'groupMetric','trade-sort':'tradeSort','image-category':'imageCategory','show-r':'showR'};if(keys[input.id]){state[keys[input.id]]=input.type==='checkbox'?input.checked:input.value;render();}
  if(input.dataset.shotCategory){const shot=draftShots.find(s=>s.id===input.dataset.shotCategory);if(shot)shot.category=input.value;}
  if(input.id==='choose-instrument'&&input.value)editor.querySelector('[name=instrument]').value=input.value;if(input.id==='liquidity-reference')editor.querySelector('[name=drawOnLiquidity]').value=input.value;
  if(input.name==='followsPlan'&&input.checked)editor.querySelectorAll('[name=brokenRules]').forEach(i=>i.checked=false);if(input.name==='brokenRules'&&input.checked)editor.querySelector('[name=followsPlan]').checked=false;
  if(input.closest('#edit-form')){updateTradePreview();if(draftKind==='review'){const form=$('#edit-form');if(form.elements.date.value)$('#review-snapshot').innerHTML=reviewSnapshot(data,form.elements.period.value,dayInstant(form.elements.date.value));}}
});
document.addEventListener('input',event=>{
  const input=event.target;if(input.closest('.image-dialog'))return;if(input.type==='range'&&input.nextElementSibling?.tagName==='OUTPUT')input.nextElementSibling.textContent=input.value;
  if(input.closest('#plan-form'))state.planDraft=Object.fromEntries(new FormData(input.form));
  if(input.id==='search'){state.filters.search=input.value;const position=input.selectionStart;clearTimeout(notify.searchTimer);notify.searchTimer=setTimeout(()=>{render();$('#search')?.focus();$('#search')?.setSelectionRange(position,position);},160);}if(input.closest('#edit-form'))updateTradePreview();
});
for(const name of ['dragover','dragleave','drop'])document.addEventListener(name,event=>{const zone=event.target.closest('.drop-zone');if(!zone)return;event.preventDefault();zone.classList.toggle('dragging',name==='dragover');if(name==='drop')addImages(event.dataTransfer.files).catch(report);});
document.addEventListener('keydown',event=>{if((event.ctrlKey||event.metaKey)&&!document.querySelector('dialog[open]')){const key=event.key.toLowerCase();if(key==='n'||key==='k'){event.preventDefault();if(key==='n')editTrade();else searchCommand();}}if(event.key==='Enter'&&event.target.classList.contains('drop-zone')){event.preventDefault();addImages().catch(report);}});
document.addEventListener('submit',async event=>{
  const form=event.target;if(form.closest('#confirm'))return;event.preventDefault();if(busy)return;busy=true;const submit=form.querySelector('[type=submit]');if(submit)submit.disabled=true;
  try{
    const fields=new FormData(form);
    if(await actions.submit(form,fields))return;
    const next=structuredClone(data);
    if(form.id==='edit-form'){
      let record;if(draftKind==='trade'){record=gatherTrade(form);next.workspace.assignments[record.id.toLowerCase()]=fields.get('workspace-accountID');next.screenshots=[...next.screenshots.filter(s=>s.tradeID!==record.id),...draftShots.map(screenshot=>({tradeID:record.id,screenshot}))];}
      else if(draftKind==='review')record={...draft,...Object.fromEntries(fields),date:dayInstant(fields.get('date'))};
      else{record={...draft,images:draftShots};for(const key of ['name','summary','conditions','entry','invalidation','target','risk'])record[key]=fields.get(key);record.name=record.name.trim();if(next.setups.some(s=>s.id!==record.id&&s.name.localeCompare(record.name,undefined,{sensitivity:'accent'})===0))throw new Error('A setup with this name already exists.');}
      const key={trade:'trades',setup:'setups',review:'reviews'}[draftKind],index=next[key].findIndex(x=>x.id===record.id);if(index<0)next[key].push(record);else next[key][index]=record;
      if(draftKind==='setup')next.trades.forEach(t=>{if(t.setupID===record.id)t.setupName=record.name;});await persist(next);editor.close();notify('Saved.');
    }else if(form.id==='preferences'){
      const sessions=fields.get('sessions').split(',').map(v=>v.trim()).filter(Boolean);next.preferences={...next.preferences,accountSize:Number(fields.get('accountSize')),defaultRiskPercent:Number(fields.get('defaultRiskPercent')),currency:fields.get('currency'),timezone:fields.get('timezone'),theme:fields.get('theme'),animations:fields.has('animations'),sessions,sessionHours:Object.fromEntries(sessions.map(s=>[s,fields.get('session:'+s)||'']))};const legacy=next.workspace.accounts.find(a=>a.id===legacyAccountID);legacy.currency=next.preferences.currency;legacy.startingBalance=next.preferences.accountSize;await persist(next);notify('Preferences saved.');
    }else if(form.id==='instruments'){
      const enabled=fields.getAll('enabled-instrument');next.instruments.forEach(i=>i.enabled=enabled.includes(i.symbol));const symbol=fields.get('new-symbol').trim().toUpperCase();if(symbol&&!next.instruments.some(i=>i.symbol===symbol))next.instruments.push({id:crypto.randomUUID(),symbol,enabled:true});await persist(next);notify('Instruments saved.');
    }else if(form.id==='rules'){const name=fields.get('new-rule').trim();if(name&&!next.rules.some(r=>r.name===name))next.rules.push({id:crypto.randomUUID(),name});await persist(next);notify('Rules saved.');}
  }catch(error){const message=errorText(error);if($('#form-error')&&editor.open){$('#form-error').textContent=message;$('#form-error').scrollIntoView({block:'nearest'});}else report(error);}finally{busy=false;if(submit)submit.disabled=false;}
});
editor.addEventListener('close',()=>{draftShots=[];draftKind=undefined;});
matchMedia('(prefers-color-scheme: light)').addEventListener('change',()=>{if(data?.preferences.theme==='System')render();});
async function start(){try{if(!api)throw new Error('Open Liquidity Edge from the installed application.');data=withWorkspace(await api.load());state.demo=false;render();}catch(error){$('#app').innerHTML=`<main><h1>Günlük açılamadı</h1><p class="error">${esc(errorText(error))}</p>${command('retry','Retry')}${api?command('recover','Restore JSON backup'):''}</main>`;$('[data-action=retry]').onclick=start;const recover=$('[data-action=recover]');if(recover)recover.onclick=async()=>{try{const restored=await api.importBackup();if(restored){data=withWorkspace(restored);state.demo=false;render();}}catch(e){report(e);}};}}
matchMedia('(prefers-reduced-motion: reduce)').addEventListener('change',()=>{if(data)render();});
start();
