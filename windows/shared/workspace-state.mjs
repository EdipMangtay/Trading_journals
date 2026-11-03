// Additive V6/V7 workspace data. Legacy journals keep their trades and IDs.
export const legacyAccountID = '00000000-0000-0000-0000-000000000001';
export const widgetNames = ['Risk & R', 'Rolling', 'Timing', 'Recent', 'Metrics'];
const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const fail = text => { throw new Error(text); };
const id = value => typeof value === 'string' && uuid.test(value) ? value.toLowerCase() : fail('Geçersiz çalışma alanı kimliği.');
const finite = value => typeof value === 'number' && Number.isFinite(value);
const positive = value => finite(value) && value > 0;
const dictionary = value => {
  if (Array.isArray(value)) { if (value.length % 2) fail('Çalışma alanı sözlüğü eksik.'); return Object.fromEntries(Array.from({ length: value.length / 2 }, (_, i) => [value[i * 2], value[i * 2 + 1]])); }
  return value ?? {};
};
export function defaultWorkspace(preferences) {
  return { accounts: [{ id: legacyAccountID, name: 'Eski günlük / varsayılan', currency: preferences.currency, startingBalance: preferences.accountSize, category: 'Personal', active: true, rules: {} }], selectedAccountID: legacyAccountID, assignments: {}, supplements: {}, templates: [], presets: [], plans: [], widgets: [...widgetNames], hiddenWidgets: [], compactRows: false, showProcess: true, showR: true };
}
export function normalizeWorkspace(value, preferences, tradeIDs) {
  const w = structuredClone(value ?? defaultWorkspace(preferences));
  if (!Array.isArray(w.accounts) || !w.accounts.length || w.accounts.length > 1000) fail('En az bir geçerli hesap gerekli.');
  const unique = records => { const ids = records.map(record => id(record.id)); if (new Set(ids).size !== ids.length) fail('Yinelenen çalışma alanı kaydı.'); };
  unique(w.accounts);
  for (const a of w.accounts) {
    a.id = id(a.id);
    if (typeof a.name !== 'string' || !a.name.trim() || !positive(a.startingBalance) || !/^[A-Z]{3}$/.test(a.currency)) fail('Hesap adı, para birimi ve bakiye geçersiz.');
    try { new Intl.NumberFormat('tr', { style: 'currency', currency: a.currency }); } catch { fail('ISO para birimi geçersiz.'); }
    a.rules ??= {}; a.category ??= 'Personal'; a.active ??= true;
    const r = a.rules;
    for (const key of ['profitTarget', 'dailyLoss', 'maximumLoss', 'riskPerTrade']) if (r[key] != null && !positive(r[key])) fail('Risk sınırları pozitif olmalı.');
    for (const key of ['minimumDays', 'dailyTradeCount']) if (r[key] != null && (!Number.isInteger(r[key]) || r[key] <= 0)) fail('Gün ve işlem sayısı pozitif tam sayı olmalı.');
    if (r.consistencyPercent != null && (!positive(r.consistencyPercent) || r.consistencyPercent > 100)) fail('Tutarlılık yüzdesi 0–100 aralığında olmalı.');
    r.drawdownMethod ??= 'Static';
    if (!['Static', 'End of day', 'Intraday equity'].includes(r.drawdownMethod)) fail('Drawdown yöntemi geçersiz.');
  }
  const accounts = new Set(w.accounts.map(a => a.id)); w.selectedAccountID = id(w.selectedAccountID);
  if (!accounts.has(legacyAccountID) || !accounts.has(w.selectedAccountID)) fail('Varsayılan veya seçili hesap bulunamadı.');
  w.assignments = Object.fromEntries(Object.entries(dictionary(w.assignments)).map(([key, value]) => [id(key), id(value)]));
  w.supplements = Object.fromEntries(Object.entries(dictionary(w.supplements)).map(([key, value]) => [id(key), value]));
  if (Object.values(w.assignments).some(value => !accounts.has(value))) fail('İşlem bulunmayan bir hesaba bağlı.');
  if (tradeIDs) { const ids = new Set([...tradeIDs].map(key => key.toLowerCase())); if ([...Object.keys(w.assignments), ...Object.keys(w.supplements)].some(key => !ids.has(key))) fail('Ek bilgiler bulunmayan bir işleme bağlı.'); }
  for (const s of Object.values(w.supplements)) {
    s.fills ??= []; s.checklist ??= []; s.pointValue ??= 1; s.tickSize ??= .01;
    if (!positive(s.pointValue) || !positive(s.tickSize) || !Array.isArray(s.fills) || !Array.isArray(s.checklist)) fail('Kontrat değerleri geçersiz.');
    unique(s.fills); unique(s.checklist);
    for (const f of s.fills) if (!finite(f.date) || !positive(f.quantity) || !finite(f.price) || !finite(f.fee) || f.fee < 0 || f.expectedPrice != null && !finite(f.expectedPrice) || !['Entry', 'Exit'].includes(f.side)) fail('Gerçekleşme bilgileri geçersiz.');
  }
  for (const key of ['templates', 'presets', 'plans']) { w[key] ??= []; if (!Array.isArray(w[key])) fail('Çalışma alanı listesi geçersiz.'); unique(w[key]); }
  for (const plan of w.plans) if (!accounts.has(id(plan.accountID)) || !finite(plan.date)) fail('Planın hesabı veya tarihi geçersiz.');
  for (const preset of w.presets) if (typeof preset.name !== 'string' || !preset.name.trim() || typeof preset.query !== 'string' || !preset.facets || typeof preset.facets !== 'object') fail('Araştırma filtresi geçersiz.');
  w.widgets = [...new Set([...(w.widgets ?? widgetNames).filter(key => widgetNames.includes(key)), ...widgetNames])];
  w.hiddenWidgets = (w.hiddenWidgets ?? []).filter(key => widgetNames.includes(key));
  return w;
}
export const selectedAccount = data => data.workspace.accounts.find(a => a.id === data.workspace.selectedAccountID);
export const accountFor = (data, tradeID) => data.workspace.assignments[tradeID.toLowerCase()] ?? legacyAccountID;
export const scopedTrades = data => data.trades.filter(t => accountFor(data, t.id) === data.workspace.selectedAccountID);
export const withWorkspace = data => ({ ...data, workspace: normalizeWorkspace(data.workspace, data.preferences, new Set(data.trades.map(t => t.id))) });
export function portableBackup(data) {
  const result = withWorkspace(data); result.version = 2;
  // Swift Codable dictionaries with UUID keys use alternating key/value arrays.
  for (const key of ['assignments', 'supplements']) result.workspace[key] = Object.entries(result.workspace[key]).flat();
  return result;
}
export function legacyBackup(data) {
  const scoped = withWorkspace(data);
  const account = selectedAccount(scoped);
  const trades = scopedTrades(scoped);
  const ids = new Set(trades.map(t => t.id.toLowerCase()));
  const { workspace, ...base } = scoped;
  return { ...base, version: 1, trades, screenshots: base.screenshots.filter(shot => ids.has(shot.tradeID.toLowerCase())),
    preferences: { ...base.preferences, currency: account.currency, accountSize: account.startingBalance } };
}
