import { dateKey, instantFromWallTime, groups, matchesSearch, compliant } from '../shared/core.mjs';
import { selectedAccount, scopedTrades, accountFor } from '../shared/workspace-state.mjs';
import { executions } from '../shared/workstation.mjs';
import { accountEditor, executionEditor, planFields, riskFields } from './workspace-pages.js';
import { previewCSV, readCSV } from './csv-workspace.js';
import { command, money } from './views.js';

export function filterRows(rows, filters, facets, zone) {
  return rows.filter(trade => {
    const day = dateKey(trade.date, zone);
    return matchesSearch(trade, filters.search ?? '')
      && (!filters.instrument || trade.instrument === filters.instrument)
      && (!filters.session || trade.session === filters.session)
      && (!filters.compliance || compliant(trade) === (filters.compliance === 'valid'))
      && (!filters.from || day >= filters.from)
      && (!filters.to || day <= filters.to)
      && Object.entries(facets).every(([key, value]) => !value || groups([trade], key, zone).some(g => g.name === value));
  });
}

const widgetLabels = { 'Risk & R': 'R ve düşüş', Rolling: 'Hareketli kazanma oranı', Timing: 'Zamanlama', Recent: 'Son işlemler', Metrics: 'Tüm ölçümler' };
const widgetFields = (widgets, hidden) => widgets.map((key, index) =>
  `<div class="line widget-row" draggable="true" data-widget="${index}"><label class="check"><input name="widget" type="checkbox" value="${key}" ${hidden.includes(key) ? '' : 'checked'}>${widgetLabels[key]}</label><div class="actions">${command('move-widget-up', 'Yukarı', 'chevron-up', `data-index="${index}" ${index === 0 ? 'disabled' : ''}`)}${command('move-widget-down', 'Aşağı', 'chevron-down', `data-index="${index}" ${index === widgets.length - 1 ? 'disabled' : ''}`)}</div></div>`).join('');

export function workspaceActions({ data, state, render, persist, showEditor, editor, notify, report }) {
  let accountDraft, executionDraft, executionTrade, widgetDraft, worker, request = 0;
  const clone = () => structuredClone(data());
  const close = () => { if (editor.open) editor.close(); };
  const applyPreset = preset => {
    const zone = data().preferences.timezone;
    return filterRows(scopedTrades(data()), { search: preset.query, from: preset.from == null ? '' : dateKey(preset.from, zone), to: preset.to == null ? '' : dateKey(preset.to, zone) }, preset.facets, zone);
  };
  const blankSupplement = () => ({ fills: [], pointValue: 1, tickSize: .01, checklist: [] });
  function gatherExecution() {
    const form = editor.querySelector('#execution-form');
    const zone = data().preferences.timezone;
    const value = (row, name) => row.querySelector(`[name="${name}"]`).value;
    executionDraft.pointValue = Number(form.elements.pointValue.value);
    executionDraft.tickSize = Number(form.elements.tickSize.value);
    executionDraft.fills = [...form.querySelectorAll('[data-fill]')].map(row => ({
      id: executionDraft.fills[Number(row.dataset.fill)].id,
      date: instantFromWallTime(value(row, 'date'), zone), side: value(row, 'side'),
      quantity: Number(value(row, 'quantity')), price: Number(value(row, 'price')), fee: Number(value(row, 'fee')),
      expectedPrice: value(row, 'expectedPrice') === '' ? undefined : Number(value(row, 'expectedPrice'))
    }));
    executionDraft.checklist = [...form.querySelectorAll('[data-checklist]')].map(row => ({
      id: executionDraft.checklist[Number(row.dataset.checklist)].id, label: value(row, 'label').trim(),
      phase: value(row, 'phase'), answer: value(row, 'answer') === '' ? undefined : value(row, 'answer') === 'true'
    }));
  }
  function redrawExecution() {
    showEditor(executionEditor(executionTrade, executionDraft, data()), 'workspace');
  }
  function invalidateSimulation() {
    request++;
    worker?.terminate();
    worker = undefined;
    state.simulation = null;
    state.simulating = false;
  }
  function moveWidget(from, to) {
    if (!widgetDraft || from === to || to < 0 || to >= widgetDraft.length) return;
    const hidden = widgetDraft.filter(key => ![...editor.querySelectorAll('[name="widget"]:checked')].some(i => i.value === key));
    const [item] = widgetDraft.splice(from, 1);
    widgetDraft.splice(to, 0, item);
    editor.querySelector('#widget-list').innerHTML = widgetFields(widgetDraft, hidden);
  }
  let dragged = null;
  editor.addEventListener('dragstart', event => {
    const row = event.target.closest('[data-widget]');
    if (row) { dragged = Number(row.dataset.widget); event.dataTransfer.setData('text/plain', row.dataset.widget); }
  });
  editor.addEventListener('dragover', event => { if (dragged != null && event.target.closest('[data-widget]')) event.preventDefault(); });
  editor.addEventListener('drop', event => {
    const row = event.target.closest('[data-widget]');
    if (dragged != null && row) { event.preventDefault(); moveWidget(dragged, Number(row.dataset.widget)); }
    dragged = null;
  });
  editor.addEventListener('dragend', () => { dragged = null; });

  async function click(action, target) {
    if (target.dataset.cohort) { state.cohort = target.dataset.cohort === state.cohort ? '' : target.dataset.cohort; render(); return true; }
    switch (action) {
      case 'new-account':
      case 'edit-account':
        accountDraft = action === 'edit-account' ? structuredClone(selectedAccount(data())) : { id: crypto.randomUUID(), name: '', currency: data().preferences.currency, startingBalance: data().preferences.accountSize, category: 'Personal', active: true, rules: {} };
        showEditor(accountEditor(accountDraft), 'workspace');
        return true;
      case 'dashboard-layout':
        widgetDraft = [...data().workspace.widgets];
        showEditor(`<form id="layout-form"><header><h2>Ana sayfa düzeni</h2>${command('close-editor', 'Kapat', 'x')}</header><div class="body"><p class="caption">Bölümleri sürükle veya oklarla sırala. Görünmesini istediklerini işaretle.</p><div id="widget-list">${widgetFields(widgetDraft, data().workspace.hiddenWidgets)}</div>${['compactRows', 'showProcess', 'showR'].map((key, i) => `<label class="check"><input type="checkbox" name="${key}" ${data().workspace[key] ? 'checked' : ''}>${['Kompakt işlem satırları','Süreç sütunu','R sütunu'][i]}</label>`).join('')}<p id="form-error" class="error"></p></div><footer class="footer"><button type="submit" class="primary">Düzeni kaydet</button></footer></form>`, 'workspace');
        return true;
      case 'move-widget-up':
      case 'move-widget-down': {
        const index = Number(target.dataset.index);
        moveWidget(index, index + (action.endsWith('up') ? -1 : 1));
        return true;
      }
      case 'delete-preset': {
        const next = clone();
        next.workspace.presets = next.workspace.presets.filter(p => p.id !== state.loadedPreset);
        state.loadedPreset = '';
        await persist(next);
        return true;
      }
      case 'edit-execution':
        executionTrade = data().trades.find(t => t.id === target.dataset.id);
        if (!executionTrade) return true;
        executionDraft = structuredClone(data().workspace.supplements[executionTrade.id.toLowerCase()] ?? blankSupplement());
        redrawExecution();
        return true;
      case 'preview-execution': {
        gatherExecution();
        const result = executions(executionDraft, executionTrade.direction);
        const account = data().workspace.accounts.find(a => a.id === accountFor(data(), executionTrade.id));
        const format = value => money(value, { preferences: { currency: account.currency } });
        editor.querySelector('#execution-preview').textContent = 'Gerçekleşen net ' + format(result.realized) + ' · Açık miktar ' + result.openQuantity + (result.slippageCost == null ? '' : ' · Kayma ' + format(result.slippageCost));
        return true;
      }
      case 'add-fill':
      case 'remove-fill':
      case 'add-check':
      case 'remove-check':
        gatherExecution();
        if (action === 'add-fill') executionDraft.fills.push({ id: crypto.randomUUID(), date: executionTrade.date, side: 'Entry', quantity: 1, price: 0, fee: 0 });
        if (action === 'remove-fill') executionDraft.fills.splice(Number(target.dataset.index), 1);
        if (action === 'add-check') executionDraft.checklist.push({ id: crypto.randomUUID(), label: '', phase: 'Öncesi' });
        if (action === 'remove-check') executionDraft.checklist.splice(Number(target.dataset.index), 1);
        redrawExecution();
        return true;
      case 'save-template': {
        gatherExecution();
        const name = editor.querySelector('[name="templateName"]').value.trim();
        if (!name || !executionDraft.checklist.length || executionDraft.checklist.some(item => !item.label)) throw new Error('Şablona bir ad ve geçerli kontrol maddeleri ekle.');
        const next = clone();
        next.workspace.templates.push({ id: crypto.randomUUID(), name, setupID: executionTrade.setupID ?? undefined, items: executionDraft.checklist.map(item => ({ ...item, answer: undefined })) });
        await persist(next);
        redrawExecution();
        notify('Kontrol listesi şablonu kaydedildi.');
        return true;
      }
      case 'apply-csv-mapping': {
        const next = clone();
        const skipDuplicates = document.querySelector('#skip-csv-duplicates').checked;
        const records = (state.csvPreview ?? []).filter(item => !item.idCollision && (!skipDuplicates || !item.duplicate));
        if (!document.querySelector('#confirm-csv-mapping').checked || !records.length) return true;
        for (const { trade } of records) {
          next.trades.push(trade);
          next.workspace.assignments[trade.id.toLowerCase()] = next.workspace.selectedAccountID;
        }
        await persist(next);
        state.csvSource = state.csvPreview = state.csvMapping = null;
        render();
        notify('CSV aktarımı tamamlandı.');
        return true;
      }
      default: return false;
    }
  }
  async function change(input) {
    const key = input.name;
    if (input.id === 'account-picker' || input.hasAttribute('data-account-picker')) {
      const next = clone();
      next.workspace.selectedAccountID = input.value;
      invalidateSimulation();
      state.planDraft = state.csvPreview = null;
      await persist(next);
      return true;
    }
    if (['researchFirst', 'researchSecond', 'comparePreset', 'scatterX', 'scatterY', 'scatterID', 'planDate'].includes(key)) {
      state[key] = input.value;
      if (key.startsWith('scatter') && key !== 'scatterID') state.scatterID = '';
      if (key === 'planDate') state.planDraft = null;
      render();
      return true;
    }
    if (key === 'scenarioRisk' || key === 'scenarioLosses') {
      if (!input.checkValidity() || input.value === '') return true;
      state[key] = Number(input.value);
      input.parentElement.parentElement.querySelector('output').textContent = money((state.scenarioRisk ?? 250) * (state.scenarioLosses ?? 5), { preferences: { currency: selectedAccount(data()).currency } });
      return true;
    }
    if (key === 'loadPreset') {
      const preset = data().workspace.presets.find(p => p.id === input.value), zone = data().preferences.timezone;
      state.loadedPreset = input.value;
      if (preset) {
        state.filters = { search: preset.query, instrument: '', session: '', compliance: '', from: preset.from == null ? '' : dateKey(preset.from, zone), to: preset.to == null ? '' : dateKey(preset.to, zone) };
        state.facets = { ...preset.facets };
        for (const [dimension, key] of [['Instrument','instrument'], ['Session','session'], ['Rule compliance','compliance']]) {
          if (!state.facets[dimension]) continue;
          state.filters[key] = key === 'compliance' ? (state.facets[dimension] === 'Fully valid' ? 'valid' : 'invalid') : state.facets[dimension];
          delete state.facets[dimension];
        }
        state.advanced = true;
        render();
      }
      return true;
    }
    if (key === 'checklistTemplate') {
      const template = data().workspace.templates.find(t => t.id === input.value);
      if (template) {
        gatherExecution();
        executionDraft.checklist.push(...template.items.map(item => ({ ...item, id: crypto.randomUUID(), answer: undefined })));
        redrawExecution();
      }
      return true;
    }
    if (input.id === 'mapped-csv' && input.files.length) {
      state.csvSource = await readCSV(input.files[0]);
      state.csvMapping = state.csvPreview = null;
      render();
      return true;
    }
    if (input.id === 'confirm-csv-mapping' || input.id === 'skip-csv-duplicates') {
      const skip = document.querySelector('#skip-csv-duplicates').checked;
      const valid = state.csvPreview?.some(item => !item.idCollision && (!skip || !item.duplicate));
      document.querySelector('[data-action="apply-csv-mapping"]').disabled = !valid || !document.querySelector('#confirm-csv-mapping').checked;
      return true;
    }
    if (input.closest('#mapping-form')) {
      state.csvMapping = Object.fromEntries(new FormData(input.form));
      state.csvPreview = null;
      document.querySelector('[data-action="apply-csv-mapping"]')?.setAttribute('disabled', '');
      return true;
    }
    return false;
  }
  async function submit(form, fields) {
    const formID = form.getAttribute('id');
    if (!['account-form','layout-form','preset-form','plan-form','execution-form','mapping-form','simulation-form'].includes(formID)) return false;
    const next = clone();
    switch (formID) {
      case 'account-form':
        Object.assign(accountDraft, { name: fields.get('name').trim(), currency: fields.get('currency').toUpperCase(), startingBalance: Number(fields.get('startingBalance')), category: fields.get('category'), active: fields.has('active') });
        accountDraft.rules = { drawdownMethod: fields.get('drawdownMethod'), ...Object.fromEntries(riskFields.filter(([key]) => fields.get(key) !== '').map(([key]) => [key, Number(fields.get(key))])) };
        next.workspace.accounts = [...next.workspace.accounts.filter(a => a.id !== accountDraft.id), accountDraft];
        next.workspace.selectedAccountID = accountDraft.id;
        invalidateSimulation();
        await persist(next); close(); notify('Hesap kaydedildi.'); return true;
      case 'layout-form':
        next.workspace.widgets = widgetDraft;
        next.workspace.hiddenWidgets = widgetDraft.filter(key => !fields.getAll('widget').includes(key));
        for (const key of ['compactRows','showProcess','showR']) next.workspace[key] = fields.has(key);
        await persist(next); close(); return true;
      case 'preset-form': {
        const name = fields.get('presetName').trim(), zone = next.preferences.timezone;
        if (!name) throw new Error('Araştırmaya bir ad ver.');
        const facets = { ...state.facets };
        if (state.filters.instrument) facets.Instrument = state.filters.instrument;
        if (state.filters.session) facets.Session = state.filters.session;
        if (state.filters.compliance) facets['Rule compliance'] = state.filters.compliance === 'valid' ? 'Fully valid' : 'Rule break';
        const preset = { id: crypto.randomUUID(), name, query: state.filters.search, facets,
          from: state.filters.from ? instantFromWallTime(state.filters.from + 'T00:00', zone) : undefined,
          to: state.filters.to ? instantFromWallTime(state.filters.to + 'T23:59', zone) + 59999 : undefined };
        next.workspace.presets.push(preset);
        state.loadedPreset = preset.id;
        await persist(next); notify('Araştırma filtresi kaydedildi.'); return true;
      }
      case 'plan-form': {
        const zone = next.preferences.timezone, accountID = next.workspace.selectedAccountID, day = state.planDate || dateKey(Date.now(), zone);
        const existing = next.workspace.plans.find(p => p.accountID.toLowerCase() === accountID && dateKey(p.date, zone) === day);
        next.workspace.plans = next.workspace.plans.filter(p => p !== existing);
        next.workspace.plans.push({ id: existing?.id ?? crypto.randomUUID(), accountID, date: instantFromWallTime(day + 'T12:00', zone), ...Object.fromEntries(planFields.map(([key]) => [key, fields.get(key)])) });
        state.planDraft = null;
        await persist(next); notify('Plan kaydedildi.'); return true;
      }
      case 'execution-form': {
        gatherExecution();
        const result = executions(executionDraft, executionTrade.direction);
        if (executionDraft.checklist.some(item => !item.label)) throw new Error('Kontrol maddeleri boş olamaz.');
        next.workspace.supplements[executionTrade.id.toLowerCase()] = executionDraft;
        if (fields.has('applyPnL')) {
          if (!executionDraft.fills.some(f => f.side === 'Exit') || result.openQuantity > 1e-9) throw new Error('Net K/Z uygulamak için pozisyonun tamamen kapanması gerekir.');
          const trade = next.trades.find(t => t.id === executionTrade.id);
          trade.grossPnL = result.realized + trade.fees;
        }
        await persist(next); close(); notify('Gerçekleşmeler kaydedildi.'); return true;
      }
      case 'mapping-form':
        state.csvMapping = Object.fromEntries(fields);
        state.csvPreview = previewCSV(state.csvSource, fields, { ...next, preferences: { ...next.preferences, currency: selectedAccount(next).currency } });
        render(); return true;
      case 'simulation-form': {
        invalidateSimulation();
        const id = request;
        state.horizon = Number(fields.get('horizon'));
        state.shuffle = fields.get('shuffle') === 'true';
        state.simulating = true;
        worker = new Worker(new URL('./simulation-worker.js', import.meta.url), { type: 'module' });
        const finish = (result, error) => {
          if (id !== request) return;
          worker.terminate(); worker = undefined;
          state.simulation = result;
          state.simulating = false;
          state.simulationReveal = Boolean(result);
          render();
          if (error) report(new Error(error));
        };
        worker.onmessage = ({ data: reply }) => finish(reply.result, reply.error);
        worker.onerror = event => { event.preventDefault(); finish(null, 'Senaryo hesabı başlatılamadı.'); };
        worker.postMessage({ id, trades: scopedTrades(next), options: { horizon: state.horizon, shuffle: state.shuffle } });
        render(); return true;
      }
      default: return false;
    }
  }
  return { click, change, submit, applyPreset, invalidateSimulation };
}
