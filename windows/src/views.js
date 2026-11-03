import { t as tr, message, errorText } from '../shared/i18n.mjs';
import Chart from 'chart.js/auto';
import { precisionChart, motionAllowed } from './precision-chart.js';
import { selectedAccount } from '../shared/workspace-state.mjs';
import { rolling } from '../shared/workstation.mjs';
import { accountPicker, accountsPage, researchPage, researchGroups, quantPage, planningPage, scatterPanel, scatterData } from './workspace-pages.js';
import { csvPage } from './csv-workspace.js';
import { catalog, net, compliant, classification, execution, performance, curve, ordered, groups, dateKey, flags, correlation } from '../shared/core.mjs';

export const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
export const glyph = name => `<i data-lucide="${name}" aria-hidden="true"></i>`;
export const command = (action, label, icon = '', extra = '') => `<button type="button" data-action="${action}" ${extra}>${icon ? glyph(icon) : ''}${tr(label)}</button>`;
const iconCommand = (action, label, icon, extra = '') => command(action, '', icon, `class="icon" aria-label="${tr(label)}" title="${tr(label)}" ${extra}`);
export const options = (values, selected, empty, localize = true) => (empty !== undefined ? `<option value="">${esc(tr(empty))}</option>` : '') + values.map(o => { const [v, label] = Array.isArray(o) ? o : [o, o]; return `<option value="${esc(v)}" ${v === selected ? 'selected' : ''}>${esc(localize ? tr(label) : label)}</option>`; }).join('');
export const field = (name, label, value = '', type = 'text', extra = '') => `<label><span>${esc(tr(label))}</span><input aria-label="${esc(tr(label))}" name="${esc(name)}" type="${type}" value="${esc(value)}" ${extra}></label>`;
export const pick = (name, label, values, selected, empty) => `<label class="inline-label"><span>${esc(tr(label))}</span><select aria-label="${esc(tr(label))}" name="${esc(name)}">${options(values, selected, empty, name !== 'setupID')}</select></label>`;
export const toggle = (name, label, checked, extra = '') => `<label class="check"><input type="checkbox" name="${name}" ${checked ? 'checked' : ''} ${extra}><span>${esc(tr(label))}</span></label>`;
export const note = (name, label, value = '') => `<label class="note"><span>${esc(tr(label))}</span><textarea aria-label="${esc(tr(label))}" name="${name}">${esc(value)}</textarea></label>`;
const num = (name, label, value, extra = '') => field(name, label, value ?? '', 'number', `step="any" ${extra}`);
const n = (value, digits = 2) => value == null ? '\u2014' : Number(value).toLocaleString('tr-TR', { minimumFractionDigits: digits, maximumFractionDigits: digits });
export const r = value => value == null ? '\u2014' : (value > 0 ? '+' : '') + n(value) + 'R';
export const pct = value => n(value, 1) + '%';
const tone = value => value > 0 ? 'positive' : value < 0 ? 'negative' : 'muted';
const classTone = t => !compliant(t) && Math.abs(net(t)) >= .005 ? 'warning' : classification(t) === 'VALID LOSER' ? 'blue' : tone(net(t));
export const badge = (label, color = 'muted') => `<span class="badge ${color}">${esc(tr(label))}</span>`;
export const money = (value, data) => new Intl.NumberFormat('tr-TR', { style: 'currency', currency: data.preferences.currency }).format(value);
const factor = p => p.profitFactor == null ? p.grossProfit > 0 ? '\u221e' : '\u2014' : n(p.profitFactor);
export const shortDate = (timestamp, data, time = false) => new Intl.DateTimeFormat('tr-TR', { dateStyle: 'medium', ...(time ? { timeStyle: 'short' } : {}), timeZone: data.preferences.timezone }).format(timestamp);
export const header = (eyebrow, title, subtitle, trailing = '') => `<header class="page-header"><div><p class="eyebrow">${tr(eyebrow)}</p><h1>${tr(title)}</h1><p class="subtitle">${tr(subtitle)}</p></div>${trailing}</header>`;
export const panel = (title, body, subtitle = '', extra = '') => `<section class="panel ${extra}">${title ? `<div class="panel-heading"><h2>${tr(title)}</h2>${subtitle ? `<small>${tr(subtitle.replaceAll('&middot;', '·'))}</small>` : ''}</div>` : ''}${body}</section>`;
export const metric = (title, value, footnote = '', color = '') => `<article class="metric"><h3>${tr(title)}</h3><strong class="${color}">${value}</strong>${footnote ? `<p>${tr(footnote)}</p>` : ''}</article>`;
const segments = (name, values, selected, label, titles = {}) => `<div class="segments" role="group" aria-label="${tr(label)}">${values.map(v => `<button data-${name}="${esc(v)}" class="${selected === v ? 'selected' : ''}" aria-pressed="${selected === v}">${esc(titles[v] ?? tr(v))}</button>`).join('')}</div>`;
export const empty = (title, subtitle, action = '') => `<div class="empty">${glyph('chart-no-axes-combined')}<h2>${tr(title)}</h2><p>${tr(subtitle)}</p>${action}</div>`;
export const navigation = [['Dashboard', 'layout-grid'], ['Trades', 'table-properties'], ['New Trade', 'square-plus'], ['Calendar', 'calendar-days'], ['Research', 'sliders-horizontal'], ['Accounts', 'landmark'], ['Quant', 'chart-line'], ['Analytics', 'chart-no-axes-combined'], ['Setup Analysis', 'layers'], ['Planning', 'list-checks'], ['Playbook', 'book'], ['Mistakes', 'shield-alert'], ['Screenshots', 'images'], ['Statistics', 'chart-column-increasing'], ['Review', 'square-check'], ['CSV Aktarım', 'file-up'], ['Settings', 'settings-2']];
export const dimensions = ['Setup', 'Instrument', 'Session', 'Day of week', 'Hour', 'Direction', 'QT quarter', 'MMXM', 'SSMT', 'TSMO', 'CRT', 'Liquidity taken', 'HTF alignment', 'Entry timeframe', 'Grade', 'Rule compliance', 'Emotion', 'Classification', 'QT validity', 'Draw on liquidity'];
export function filterBar(data, state) {
  const f = state.filters, count = Object.entries(f).filter(([key, value]) => key !== 'search' && value).length + Object.values(state.facets).filter(Boolean).length;
  return `<section class="filter-bar"><div class="filter-search">${glyph('search')}<input type="search" id="search" aria-label="İşlemlerde ara" data-filter="search" value="${esc(f.search)}" placeholder="Enstrüman, model, duygu veya not ara…">${command('toggle-filters', `Filters ${count}`, 'list-filter')}${command('reset-filters', 'Reset', '', 'class="plain"')}</div>${state.advanced ? `<div class="form-grid filter-options">${[['instrument', 'Instrument', [...new Set(data.trades.map(t => t.instrument))]], ['session', 'Session', data.preferences.sessions], ['compliance', 'Rule compliance', [['valid', 'Valid'], ['invalid', 'Rule break']]]].map(([key, label, values]) => `<label class="inline-label"><span>${tr(label)}</span><select data-filter="${key}" aria-label="${tr(label)}">${options(values, f[key], 'All')}</select></label>`).join('')}${dimensions.filter(d => !['Instrument','Session','Rule compliance'].includes(d)).map(d => `<label class="inline-label"><span>${tr(d)}</span><select data-facet="${esc(d)}">${options(groups(data.trades, d, data.preferences.timezone).map(g => g.name), state.facets[d] || '', 'All', d !== 'Setup')}</select></label>`).join('')}<label>Başlangıç<input data-filter="from" type="date" value="${esc(f.from)}"></label><label>Bitiş<input data-filter="to" type="date" value="${esc(f.to)}"></label></div>` : ''}</section>`;
}
export function tradeRows(rows, data, { selected, inert = false, compact = false } = {}) {
  return `<div class="trade-rows ${compact ? 'compact' : ''} ${data.workspace?.showProcess === false ? 'hide-process' : ''} ${data.workspace?.showR === false ? 'hide-r' : ''}"><div class="trade-row headings"><span>ENSTRÜMAN / STRATEJİ</span><span>SÜREÇ</span><span>NET K/Z</span><span>R</span></div>${rows.map(t => `<${inert ? 'div' : 'button'} class="trade-row ${selected === t.id ? 'selected' : ''}" ${inert ? '' : `data-trade="${t.id}" aria-label="İşlemi incele: ${esc(t.instrument)}"`}><span class="instrument-cell"><span class="direction-icon">${glyph(t.direction === 'Long' ? 'arrow-up-right' : 'arrow-down-right')}</span><span class="trade-label"><span><b>${esc(t.instrument)}</b><small>${esc(tr(t.direction.toUpperCase()))}</small><small>${shortDate(t.date, data)}</small></span><small>${esc(t.setupName)} &middot; ${esc(tr(t.session))}</small></span></span><span>${badge(classification(t), classTone(t))}</span><span class="${tone(net(t))}">${money(net(t), data)}</span><span class="${tone(t.rMultiple || 0)}">${r(t.rMultiple)}</span></${inert ? 'div' : 'button'}>`).join('')}</div>`;
}
function metricGrid(p, data) {
  return `<div class="metrics">${[
    ['Profit factor', factor(p)], ['Expectancy / trade', money(p.expectancy, data)], ['Average winner', money(p.averageWinner, data)], ['Average loser', money(p.averageLoser, data)],
    ['Average R', r(p.averageR)], ['Best trade', money(p.bestTrade, data)], ['Worst trade', money(p.worstTrade, data)], ['Max drawdown', money(p.maxDrawdown, data)],
    ['Current win streak', p.currentWinStreak], ['Current loss streak', p.currentLossStreak], ['Rule compliance', pct(p.compliance)], ['Total trades', p.count],
    ['Loss rate', pct(p.lossRate)], ['Recovery factor', n(p.recoveryFactor)], ['Realized payoff ratio', n(p.payoffRatio)], ['Average duration', p.averageDuration == null ? '\u2014' : n(p.averageDuration / 60, 0) + ' min']
  ].map(([title, value]) => metric(title, value)).join('')}</div>`;
}
export function chart(id, height = 260, extra = '') { return `<div class="chart" style="height:${height}px"><canvas id="${id}" ${extra}></canvas></div>`; }
function heatmap(rows, data) {
  const buckets = new Map();
  const formatter = new Intl.DateTimeFormat('en-US', { weekday: 'short', hour: '2-digit', minute: '2-digit', hourCycle: 'h23', timeZone: data.preferences.timezone });
  for (const t of rows) { const parts = formatter.formatToParts(t.date), part = name => parts.find(p => p.type === name).value; const key = `${part('weekday')}-${+part('hour') * 2 + (+part('minute') >= 30 ? 1 : 0)}`; if (!buckets.has(key)) buckets.set(key, []); buckets.get(key).push(t); }
  const slots = Array.from({ length: 48 }, (_, i) => i);
  const observations = new Map([...buckets].map(([key, trades]) => [key, performance(trades)]));
  const intensity = Math.max(1, ...[...observations.values()].map(p => Math.abs(p.averageR ?? 0)));
  let animated = 0;
  return `<div class="heatmap-scroll"><div class="heatmap"><span class="muted">GÜN</span>${slots.map(s => `<span class="muted">${String(Math.floor(s / 2)).padStart(2, '0')}:${s % 2 ? '30' : '00'}</span>`).join('')}${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map(day => `<span class="day-label">${tr(day)}</span>${slots.map(s => { const p = observations.get(`${day}-${s}`) ?? { count: 0, averageR: null }; return `<span class="heat-cell ${p.averageR == null ? '' : tone(p.averageR)}" ${p.count ? 'tabindex="0"' : ''} ${p.count && animated < 12 ? `data-heat-enter style="--heat-delay:${animated++ * 10}ms;--intensity:${Math.abs(p.averageR ?? 0) / intensity}"` : `style="--intensity:${Math.abs(p.averageR ?? 0) / intensity}"`} title="${tr(day)}: n = ${p.count}, ${r(p.averageR)}" aria-label="${tr(day)} ${String(Math.floor(s / 2)).padStart(2,'0')}:${s % 2 ? '30' : '00'}, ${p.count} işlem, ${r(p.averageR)}">${p.averageR == null ? '&middot;' : n(p.averageR, 1)}</span>`; }).join('')}`).join('')}</div></div><p class="caption">Ortalama R · Negatif / pozitif · yarım saatlik giriş aralıkları · ${esc(data.preferences.timezone)}</p>`;
}
function dashboard(data, state, rows) {
  const p = performance(rows), account = selectedAccount(data);
  const figures = [
    ['NET SONUÇ', money(p.netPnL, data), tone(p.netPnL)],
    ['ORTALAMA R', r(p.averageR), tone(p.averageR)],
    ['KAZANMA ORANI', pct(p.winRate)], ['KÂR FAKTÖRÜ', factor(p)], ['ÖRNEKLEM', 'n = ' + p.count]
  ];
  const title = header('PERFORMANCE / 01', 'Performans masası', esc(account.name) + ' · ' + account.currency, command('dashboard-layout', 'Düzen', 'sliders-horizontal'));
  const metrics = `<div class="metrics terminal-metrics dashboard-metrics">${figures.map(([title, value, color]) => metric(title, rows.length || title === 'ÖRNEKLEM' ? value : '—', '', color)).join('')}</div>`;
  const controls = `<div class="line dashboard-controls">${segments('period', ['TODAY', 'THIS WEEK', 'THIS MONTH', 'ALL TIME'], state.period, 'Dashboard period')}${segments('curve-mode', ['$', 'R', '%'], state.curveMode, 'Equity curve unit', { '$': account.currency })}</div>`;
  if (!rows.length) return title + metrics + controls + empty(
    data.trades.length ? 'Bu aralıkta işlem yok.' : 'Bir sonraki kararın, bugünkü kaydınla başlar.',
    'İşlemlerini kaydet, kararlarını incele, gelişimini izle. Grafikler gerçek kayıtlarınla oluşur.',
    command('new-trade', 'New trade', 'plus', 'class="primary"') + (!state.demo ? command('demo', 'Örnek günlüğü keşfet') : '')
  );
  const discipline = `<aside class="dashboard-discipline"><p class="eyebrow">SÜREÇ / DİSİPLİN</p><div class="quality-score"><strong>${n(p.executionScore, 0)}</strong><span>/ 100</span></div><progress value="${p.executionScore}" max="100"></progress><div class="line"><span>Plana uyum</span><b>${pct(p.compliance)}</b></div>
    ${['VALID WINNER', 'VALID LOSER', 'INVALID WINNER', 'INVALID LOSER', 'BREAKEVEN'].map((type, i) => `<div class="line outcome"><span><i class="dot ${['positive','blue','warning','warning','muted'][i]}"></i>${tr(type)}</span><b>${rows.filter(t => classification(t) === type).length}</b></div>`).join('')}
    <small>A+ kazanma oranı</small><strong>${p.aPlusWinRate == null ? '—' : pct(p.aPlusWinRate)}</strong></aside>`;
  const plots = {
    'Risk & R': `<div class="two-columns">${panel('R / RİSK BİRİMİ', chart('cumulative-r', 185), `${p.rCount} kayıtlı R · ${r(p.totalR)} toplam`)}${panel('DRAWDOWN / ZİRVEDEN UZAKLIK', chart('drawdown', 185), 'Maksimum ' + money(p.maxDrawdown, data))}</div>`,
    Rolling: panel('HAREKETLİ KAZANMA ORANI', chart('rolling', 165), 'Son 20 işlem · İlk pencerelerde mevcut örneklem'),
    Timing: panel('ZAMANLAMA / ORTALAMA R', heatmap(rows, data), esc(data.preferences.timezone)),
    Recent: panel('SON İŞLEMLER', tradeRows([...rows].sort((a,b) => b.date - a.date).slice(0,6), data), 'Bir kayıt seçerek ayrıntıları incele'),
    Metrics: `<details class="panel"><summary>Tüm performans ölçümleri</summary><div class="details-body">${metricGrid(p, data)}</div></details>`
  };
  return title + metrics + controls + `<div class="dashboard-hero">${panel('Sermaye gelişimi', chart('equity', 285) + `<div class="chart-footer"><span>Doğrusal · kayıt sırası korunur</span><span>${p.rCount} / ${p.count} R kaydı</span></div>`, 'NET / ' + tr(state.period), 'hero-chart')}${discipline}</div>` +
    data.workspace.widgets.filter(key => !data.workspace.hiddenWidgets.includes(key)).map(key => plots[key]).join('');
}
export function groupTable(cohorts, data) {
  return `<div class="table-wrap"><table class="group-table"><thead><tr>${['COHORT', 'N', 'WR', 'AVG R', 'NET PNL', 'EXPECTANCY', 'PF'].map(c => `<th>${tr(c)}</th>`).join('')}</tr></thead><tbody>${cohorts.map(p => `<tr><td>${esc(data.localizeGroups ? tr(p.name) : p.name)}</td><td>${p.count}</td><td>${pct(p.winRate)}</td><td class="${tone(p.averageR || 0)}">${r(p.averageR)}</td><td>${money(p.netPnL, data)}</td><td>${money(p.expectancy, data)}</td><td>${factor(p)}</td></tr>`).join('')}</tbody></table></div>`;
}
function comparisons(rows) {
  const definitions = [
    ['SSMT contribution', 'With valid SSMT', 'Without valid SSMT', t => flags(t).SSMT, t => !flags(t).SSMT],
    ['TSMO contribution', 'With valid TSMO', 'Without valid TSMO', t => flags(t).TSMO, t => !flags(t).TSMO],
    ['Quarter alignment', 'QT aligned', 'QT not aligned', t => t.qt.enabled && t.qt.aligned, t => t.qt.enabled && !t.qt.aligned],
    ['Liquidity sweep', 'Valid sweep', 'No valid sweep', t => t.sweepValid, t => !t.sweepValid],
    ['CRT \u00d7 SSMT', 'CRT + SSMT', 'CRT without SSMT', t => flags(t).CRT && flags(t).SSMT, t => flags(t).CRT && !flags(t).SSMT],
    ['MMXM \u00d7 QT', 'MMXM + QT', 'MMXM without QT', t => flags(t).MMXM && flags(t).QT, t => flags(t).MMXM && !flags(t).QT],
    ['Process advantage', 'Fully valid trades', 'Rule break trades', compliant, t => !compliant(t)]
  ];
  return `<h2 class="section-label">TEYİTLERİN KATKISI</h2><div class="two-columns">${definitions.map(([title, a, b, left, right]) => panel(title.toUpperCase(), [[a, left], [b, right]].map(([name, filter]) => { const p = performance(rows.filter(filter)); return `<div class="comparison-row"><div><strong>${tr(name)}</strong><small>n = ${p.count} &middot; ${pct(p.winRate)} WR</small></div><b class="${tone(p.averageR || 0)}">${r(p.averageR)}</b></div>`; }).join('') + "<p class=\"caption\">Betimleyici karşılaştırma; grupların stratejileri ve uygulamaları farklı olabilir.</p>")).join('')}</div>`;
}
function edges(rows) {
  const buckets = new Map(), names = ['QT', 'MMXM', 'SSMT', 'TSMO', 'CRT'];
  for (const t of rows) {
    const f = flags(t), active = names.filter(name => f[name]);
    const add = name => { if (!buckets.has(name)) buckets.set(name, []); buckets.get(name).push(t); };
    if (active.length === 1) add(active[0] + ' Only');
    for (let mask = 1; mask < 32; mask++) { const selected = names.filter((_, i) => mask & (1 << i)); if (selected.length >= 2 && selected.every(name => f[name])) add(selected.join(' + ')); }
  }
  return [...buckets].map(([name, rows]) => ({ name, ...performance(rows) })).sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));
}
function analytics(data, state, rows) {
  const p = performance(rows), cohorts = groups(rows, state.analysis, data.preferences.timezone), stats = state.view === 'Statistics';
  const title = state.view === 'Setup Analysis' ? 'Find the combinations that matter.' : stats ? 'Your performance, precisely.' : 'Evidence over intuition.';
  const top = header('Research desk', title, 'Measure confirmations against your own execution history.') + filterBar(data, state);
  if (!rows.length) return top + empty('No observations yet.', 'Add trades or adjust filters to begin your analysis.');
  const months = new Map(); for (const t of rows) { const key = dateKey(t.date, data.preferences.timezone).slice(0, 7); if (!months.has(key)) months.set(key, []); months.get(key).push(t); }
  const relationship = correlation([...months.values()].map(trades => performance(trades)).filter(p => p.averageR != null).map(p => [p.compliance, p.averageR]));
  return top + (stats ? metricGrid(p, data) : `<div class="metrics">${metric('Sample', `n = ${p.count}`)}${metric('Win rate', pct(p.winRate))}${metric('Expectancy', r(p.averageR))}${metric('Compliance', pct(p.compliance))}</div>`) +
    panel('PERFORMANCE BREAKDOWN', `<div class="line pickers"><label class="inline-label">Gruplama<select id="dimension">${options(dimensions, state.analysis)}</select></label><label class="inline-label">Ölçüt<select id="group-metric">${options(['Average R', 'Win rate', 'Net PnL', 'Expectancy', 'Profit factor'], state.groupMetric)}</select></label></div>${chart('group-bars', Math.max(160, cohorts.length * 33))}${groupTable(cohorts, {...data, localizeGroups: !['Setup', 'Instrument'].includes(state.analysis)})}`) +
    (stats ? '' : comparisons(rows) + panel('EDGE MATRIX', edges(rows).map(e => `<div class="edge-row"><div><strong>${tr(e.name)}</strong>${badge(e.count < 30 ? 'LOW SAMPLE' : e.count < 50 ? 'REASONABLE SAMPLE' : 'MORE EVIDENCE', e.count < 30 ? 'warning' : 'positive')}</div><div><p>${pct(e.winRate)} KO &middot; ${r(e.averageR)} beklenti</p><small>Kazananlarda ort. R ${r(e.averageWinningR)} &middot; n = ${e.count}</small></div></div>`).join('') + "<p class=\"caption\">Birleşimler ek teyitli işlemleri de içerir. Örneklem büyüklüğü tek başına istatistiksel güven veya kalıcı avantaj sağlamaz.</p>", 'CONFIRMED MODEL COMBINATIONS')) +
    panel('DISCIPLINE OVER TIME', chart('discipline-chart', 170) + [...months].sort().map(([month, trades]) => { const stats = performance(trades); return `<div class="line"><span>${month}</span><span>${pct(stats.compliance)} &nbsp; ${r(stats.averageR)}</span></div>`; }).join('') + `<p class="caption">${tr(relationship == null ? 'Correlation needs at least three months with recorded R and variation in both metrics.' : `Monthly compliance / expectancy Pearson r = ${n(relationship)}. Association is not causation; ${months.size} monthly observations.`)}</p>`, 'MONTHLY RULE COMPLIANCE') +
    scatterPanel(rows, data, state) + panel('SESSION PERFORMANCE', groupTable(groups(rows, 'Session', data.preferences.timezone), {...data, localizeGroups: true})) + panel('ENTRY TIME HEATMAP', heatmap(rows, data)) + panel('METRIC DEFINITIONS', `<p class="caption">K/Z ölçütleri brüt sonuçtan masrafların çıkarılmasıyla hesaplanır. Kazanma ve kaybetme oranlarının paydasına başabaş işlemler de dahildir. Beklenti, net K/Z'nin işlem sayısına bölümüdür. R beklentisi ve ortalama R, toplam kayıtlı R'nin R kaydı olan işlem sayısına bölümüdür. Kazananların ortalama R'si yalnızca kazanan işlemleri içerir. Kâr faktörü net kazançların mutlak net zararlara oranıdır. Düşüş sıfır birikimli K/Z'den başlar. Yüzdelik bakiye, para yatırma ve çekme olmadan başlangıç hesabını kullanır. Başabaş işlemler seriyi sıfırlar. Seanslar elle seçilir; saat grupları işlem saat dilimini kullanır. Çok etiketli gruplar örtüşebilir.</p>`);
}
function calendar(data, state) {
  const year = state.month.getFullYear(), month = state.month.getMonth(), first = new Date(year, month, 1), count = new Date(year, month + 1, 0).getDate(), offset = (first.getDay() + 6) % 7;
  const prefix = `${year}-${String(month + 1).padStart(2, '0')}`, rows = data.trades.filter(t => dateKey(t.date, data.preferences.timezone).startsWith(prefix)), p = performance(rows);
  const dayRows = key => rows.filter(t => dateKey(t.date, data.preferences.timezone) === key), today = dateKey(Date.now(), data.preferences.timezone);
  return header('Session by session', 'The rhythm of your trading.', 'Daily outcomes, with the process one click away.', `<label class="check">R göster<input id="show-r" type="checkbox" ${state.showR ? 'checked' : ''}></label>`) +
    `<div class="metrics">${metric('Monthly PnL', money(p.netPnL, data))}${metric('Monthly R', r(p.totalR))}${metric('Win rate', pct(p.winRate))}${metric('Trades', p.count)}</div>` +
    panel('', `<div class="line month-controls"><div>${iconCommand('month-prev', 'Previous month', 'chevron-left')}<strong>${first.toLocaleDateString('tr-TR', { month: 'long', year: 'numeric' })}</strong>${iconCommand('month-next', 'Next month', 'chevron-right')}</div>${command('month-today', 'This month')}</div><div class="calendar">${['MON','TUE','WED','THU','FRI','SAT','SUN'].map(d => `<span class="weekday">${tr(d)}</span>`).join('')}${Array.from({ length: offset }, () => '<span></span>').join('')}${Array.from({ length: count }, (_, i) => {
      const key = `${prefix}-${String(i + 1).padStart(2, '0')}`, trades = dayRows(key), stats = performance(trades), value = state.showR ? stats.totalR : stats.netPnL;
      return `<button class="day ${trades.length ? tone(value) : ''} ${state.selectedDay === key ? 'selected' : ''}" data-day="${key}"><span>${i + 1}${key === today ? '<i class="dot positive"></i>' : ''}</span>${trades.length ? `<strong>${state.showR ? r(value) : money(value, data)}</strong><small>${trades.length} işlem</small>` : ''}</button>`;
    }).join('')}</div>`) + (state.selectedDay ? panel(state.selectedDay, dayRows(state.selectedDay).length ? tradeRows(dayRows(state.selectedDay), data) : "<p class=\"muted\">Bu gün işlem yok.</p>") : '');
}
function playbook(data) {
  return header('Your models', 'Define it. Execute it. Refine it.', 'A living playbook, linked to the performance of your actual trades.', command('new-setup', 'New setup', '', 'class="primary"')) +
    (data.setups.length ? [...data.setups].sort((a,b) => a.name.localeCompare(b.name)).map((s, index) => { const p = performance(data.trades.filter(t => t.setupID === s.id)); return panel('', `<div class="model-head"><div><p class="eyebrow positive">MODEL ${String(index + 1).padStart(2, '0')}</p><h2>${esc(s.name)}</h2><p class="subtitle">${esc(s.summary)}</p></div><div class="actions">${command('edit-setup', 'Edit', '', `data-id="${s.id}"`)}${iconCommand('delete-setup', 'Delete setup', 'trash-2', `data-id="${s.id}"`)}</div></div><div class="model-metrics">${[['SAMPLES', p.count], ['WIN RATE', pct(p.winRate)], ['AVG R', r(p.averageR)], ['EXPECTANCY', money(p.expectancy, data)], ['COMPLIANCE', pct(p.compliance)]].map(([label, value]) => `<div><small>${tr(label)}</small><strong>${value}</strong></div>`).join('')}</div><details><summary>Koşullar ve uygulama kuralları</summary><div class="details-body">${['conditions', 'entry', 'invalidation', 'target', 'risk'].map(key => `<div class="read-note"><small>${tr(key.toUpperCase())}</small><p>${esc(s[key] || tr('Not recorded'))}</p></div>`).join('')}${imageGallery(s.images)}</div></details>`); }).join('') : empty('Codify your first setup.', 'Write the conditions, invalidation and risk rules that make an execution valid.', command('new-setup', 'Create setup', '', 'class="primary"')));
}
function mistakes(data) {
  const mistakes = groups(data.trades, 'Mistakes').sort((a,b) => b.count - a.count);
  return header('Process audit', 'The cost of breaking your rules.', 'Profitable mistakes are still mistakes. Learn from the process.') +
    (mistakes.length ? mistakes.map(m => panel('', `<div class="line"><div><h2 class="regular-title">${esc(tr(m.name))}</h2><p class="subtitle">${m.count} trades &middot; ${pct(m.winRate)} kazanma oranı</p></div><strong class="warning large-number">${r(m.totalR)}</strong><span class="muted large-number">${money(m.netPnL, data)}</span></div>${m.netPnL > 0 ? "<p class=\"warning\">Olumlu sonuç, zayıf süreç</p>" : ''}`)).join('') + "<p class=\"caption\">Bir işlem birden çok kuralı ihlal edebilir; işlem sayıları ve K/Z hatalar arasında örtüşebilir.</p>" : empty('No rule violations recorded.', 'Honest process reviews are the foundation of a useful journal.'));
}
function reviews(data) {
  return header('Deliberate practice', 'Turn experience into improvement.', 'Daily, weekly and monthly reviews anchored in your trade data.', command('new-review', 'New review', '', 'class="primary"')) +
    (data.reviews.length ? [...data.reviews].sort((a,b) => b.date - a.date).map(item => panel('', `<div class="line"><div>${badge(item.period.toUpperCase(), 'positive')}<h2 class="regular-title">${shortDate(item.date, data)}</h2><p class="subtitle">${esc(item.adjustment || item.worked || tr('No adjustment recorded.'))}</p></div><div class="actions">${command('edit-review', 'Open review', '', `data-id="${item.id}"`)}${iconCommand('delete-review', 'Delete review', 'trash-2', `data-id="${item.id}"`)}</div></div>`)).join('') : empty('Build a review habit.', 'Capture what worked, what did not, and one adjustment for your next session.'));
}
export function imageGallery(images, editable = false) {
  return `<div class="gallery">${images.map(s => `<article class="shot"><button class="image-button" data-shot="${s.id}" type="button"><img src="data:image/jpeg;base64,${esc(s.thumbnailData)}" alt="${esc(s.name)}"></button><footer>${editable ? `<select aria-label="Görsel kategorisi" data-shot-category="${s.id}">${options(catalog.screenshotCategories, s.category)}</select>${iconCommand('remove-shot', 'Remove image', 'trash-2', `data-id="${s.id}"`)}` : badge(s.category)}<small>${esc(s.name)}</small></footer></article>`).join('')}</div>`;
}
function screenshots(data, state) {
  const shots = data.screenshots.filter(s => !state.imageCategory || s.screenshot.category === state.imageCategory);
  return header('Visual memory', 'Build your pattern library.', 'Context, entry and review images linked to real executions.') + `<div class="line"><label class="inline-label">Kategori<select id="image-category">${options(catalog.screenshotCategories, state.imageCategory, 'All screenshots')}</select></label><small>${shots.length} görsel</small></div>` +
    (shots.length ? `<div class="gallery">${shots.map(({tradeID,screenshot:s})=>{const t=data.trades.find(t=>t.id===tradeID);return `<article class="panel shot"><button class="image-button" data-shot="${s.id}"><img src="data:image/jpeg;base64,${esc(s.thumbnailData)}" alt="${esc(s.name)}"></button><div class="line"><strong>${esc(t?.instrument)}</strong>${badge(s.category)}<span class="${tone(t?net(t):0)}">${r(t?.rMultiple)}</span></div><button data-trade="${tradeID}" class="plain">İşlemi aç ${glyph('arrow-right')}</button></article>`;}).join('')}</div>` : empty('Your visual library is empty.', 'Attach screenshots to a trade. Review them here by stage.'));
}
function settings(data, state) {
  const p = data.preferences;
  return header('Workspace preferences', 'Make it your journal.', 'Local storage, clear defaults and data you control.') +
    `<form id="preferences" class="stack">${panel('ACCOUNT & APPEARANCE', `<div class="form-grid account-fields">${num('accountSize', 'Account size', p.accountSize, 'required min="0.01"')}${num('defaultRiskPercent', 'Default risk %', p.defaultRiskPercent, 'required min="0" max="100"')}${field('currency', 'Currency', p.currency, 'text', 'maxlength="3" required pattern="[A-Z]{3}"')}</div><div class="line">${pick('theme', 'Theme', ['Dark','Light','System'], p.theme)}${toggle('animations', 'Animations', p.animations)}</div>${field('timezone', 'Time zone', p.timezone, 'text', 'required')}<p class="caption">America/New_York veya Europe/Istanbul gibi bir IANA saat dilimi kullan. Takvim ve saat analizleri bu dilime göre gösterilir; zaman damgaları değişmez. Para birimi yalnızca gösterimi değiştirir, kur dönüşümü yapmaz.</p><div><button type="submit">Tercihleri kaydet</button></div>`)}
    ${panel('TRADING SESSIONS', `<div id="session-fields">${p.sessions.map(s => `<div class="session-row"><span>${esc(tr(s))}</span><input name="session:${esc(s)}" aria-label="${esc(s)} session hours" value="${esc(p.sessionHours[s] || '')}">${iconCommand('remove-session', 'Remove session', 'circle-minus', `data-id="${esc(s)}"`)}</div>`).join('')}</div><div class="line"><input id="custom-session" aria-label="Özel seans" placeholder="Özel seans">${command('add-session', 'Add session')}</div><input type="hidden" name="sessions" value="${esc(p.sessions.join(', '))}"><p class="caption">Seans saatleri referans takvimindir. Her işlemde seansı kendin seç. Değişiklikler için tercihleri kaydet.</p>`)}</form>` +
    panel('ALLOWED INSTRUMENTS', `<form id="instruments"><div class="checklist">${data.instruments.map(i => toggle('enabled-instrument', i.symbol, i.enabled, `value="${esc(i.symbol)}"`)).join('')}</div><div class="line"><input name="new-symbol" aria-label="Özel sembol" placeholder="Özel sembol"><button type="submit">Enstrüman ekle / Kaydet</button></div></form>`) +
    panel('CUSTOM RULES', `<form id="rules"><div class="line"><input name="new-rule" aria-label="Kural adı" placeholder="Kural adı"><button type="submit">Kural ekle</button></div>${data.rules.map(item => `<div class="line"><span>${esc(item.name)}</span>${iconCommand('remove-rule', 'Remove rule', 'circle-minus', `data-id="${item.id}"`)}</div>`).join('')}</form>`) +
    panel('BACKUP & PORTABILITY', `<div class="actions">${command('export-backup', 'Export JSON backup', 'download')}${command('export-legacy', 'Seçili hesabı V1 olarak dışa aktar', 'download')}${command('import-backup', 'Restore JSON backup', 'upload')}${command('export-csv', 'Export CSV', 'file-down')}${command('import-csv', 'Import CSV', 'file-up')}</div><p class="caption">Tam JSON yedeği hesapları, gerçekleşmeleri, kontrol listelerini ve planları içerir. CSV ve V1, seçili hesabın işlem kayıtlarını aktarır.</p><p class="caption" id="data-path"></p>`) +
    panel('WORKSPACE', `<div class="line"><span>${state.demo ? tr('Demo workspace') : tr('Your personal journal')}</span>${command(state.demo ? 'exit-demo' : 'demo', state.demo ? 'Start My Journal' : 'Open Demo')}</div>`);
}
export function workspaceView(data, state, rows, allData, applyPreset) {
  let content;
  if (state.view === 'Dashboard') content = dashboard(data, state, rows);
  else if (state.view === 'Trades') {
    const sorted = [...rows].sort((a,b) => state.tradeSort === 'Oldest' ? a.date - b.date : state.tradeSort === 'Best R' ? (b.rMultiple ?? -Infinity) - (a.rMultiple ?? -Infinity) : state.tradeSort === 'Best PnL' ? net(b) - net(a) : b.date - a.date);
    const selected = sorted.find(t => t.id === state.selectedTrade);
    const inspector = selected ? panel('İŞLEM ÖNİZLEMESİ',
      `<div class="line"><h2>${esc(selected.instrument)}</h2>${badge(selected.direction.toUpperCase())}</div><p>${esc(selected.setupName)} · ${shortDate(selected.date, data, true)}</p>
      <div class="line"><strong class="${tone(net(selected))}">${money(net(selected),data)}</strong><strong>${r(selected.rMultiple)}</strong></div>
      ${badge(classification(selected), classTone(selected))}<p class="caption">${esc(selected.notes.thesis || selected.notes.lesson)}</p>
      ${command('open-source', 'Tam ayrıntıyı aç', 'arrow-up-right', `data-id="${selected.id}" class="primary"`)}
      ${command('edit-execution', 'Gerçekleşmeler', 'list-checks', `data-id="${selected.id}"`)}`, '', 'trade-inspector') : '';
    content = header('EXECUTION / LOG', 'Her işlem bir karar.', `${rows.length} işlem · Ara, incele ve sürecini geliştir.`,
      `<label class="inline-label">Sırala<select id="trade-sort">${options(['Newest','Oldest','Best R','Best PnL'], state.tradeSort)}</select></label>`) +
      filterBar(data, state) + (rows.length
        ? `<div class="trade-workspace ${selected ? 'has-inspector' : ''}">${panel('', tradeRows(sorted, data, { selected: selected?.id, compact: data.workspace.compactRows }))}${inspector}</div>`
        : empty(data.trades.length ? 'No matching trades.' : 'Your journal is ready.', data.trades.length ? 'Change your search or reset the filters.' : 'Start with a quick entry. Add context when you review.', command('new-trade','New trade','','class="primary"')));
  }
  else if (['Analytics','Setup Analysis','Statistics'].includes(state.view)) content = analytics(data, state, rows);
  else if (state.view === 'Accounts') content = accountsPage(data, rows, allData);
  else if (state.view === 'Research') content = researchPage(data, state, rows, applyPreset);
  else if (state.view === 'Quant') content = quantPage(data, state, rows);
  else if (state.view === 'Planning') content = planningPage(data, state, rows);
  else if (state.view === 'CSV Aktarım') content = csvPage(data, state);
  else if (state.view === 'Calendar') content = calendar(data, state);
  else if (state.view === 'Playbook') content = playbook(data);
  else if (state.view === 'Mistakes') content = mistakes(data);
  else if (state.view === 'Review') content = reviews(data);
  else if (state.view === 'Screenshots') content = screenshots(data,state);
  else content = settings(allData, state);
  return `<aside class="sidebar ${state.collapsed ? 'collapsed' : ''}"><div class="brand"><span class="brand-mark">${glyph('audio-waveform')}</span><div><strong>LIQUIDITY</strong><span>EDGE</span></div></div><nav class="nav">${navigation.filter(([name]) => !['New Trade','Settings'].includes(name)).map(([name, icon]) => `${({ Dashboard: '<p class="nav-section">GÜNLÜK</p>', Research: '<p class="nav-section">PERFORMANS</p>', Planning: '<p class="nav-section">GELİŞİM</p>' })[name] ?? ''}<button aria-current="${state.view === name ? 'page' : 'false'}" ${name === 'New Trade' ? 'data-action="new-trade"' : `data-view="${name}"`} class="${state.view === name ? 'active' : ''}" title="${tr(name)}">${glyph(icon)}<span>${tr(name)}</span>${name === 'New Trade' ? '<small>Ctrl N</small>' : ''}</button>`).join('')}</nav><nav class="nav nav-settings"><button data-view="Settings" title="Ayarlar" aria-current="${state.view === 'Settings' ? 'page' : 'false'}" class="${state.view === 'Settings' ? 'active' : ''}">${glyph('settings-2')}<span>Ayarlar</span></button></nav><div class="sidebar-bottom"><strong>${state.demo ? 'Örnek çalışma alanı' : 'Bu bilgisayarda saklanıyor'}</strong><p>${state.demo ? 'Örnek veriler günlüğünü etkilemez.' : 'Verilerin yerel olarak kaydedilir.'}</p></div>${iconCommand('collapse-sidebar', 'Toggle sidebar', 'panel-left')}</aside>
    <div class="workspace ${state.collapsed ? 'collapsed' : ''}"><div class="topbar"><div class="breadcrumb">${glyph(navigation.find(([name]) => name === state.view)?.[1] ?? 'layout-grid')}<div><small>ÇALIŞMA ALANI</small><strong>${tr(state.view)}</strong></div></div><div class="actions">${accountPicker(data)}${iconCommand('export-pdf', 'PDF olarak kaydet', 'file-down')}${command('search-command', `${glyph('search')}Ara <small>Ctrl K</small>`, '', 'class="search-command"')}${command('new-trade','New trade','plus','class="primary"')}</div></div>${state.demo ? `<div class="demo-banner">${badge('DEMO WORKSPACE','warning')}<span>28 örnek işlemi incele. Kendi günlüğün ayrı tutulur.</span>${command('exit-demo','Start My Journal')}</div>` : ''}<main>${content}</main></div>`;
}
export function drawCharts(data, state, rows) {
  const style = getComputedStyle(document.documentElement);
  const color = name => style.getPropertyValue('--' + name).trim();
  const green = color('mint'), red = color('red'), blue = color('blue'), muted = color('muted');
  const charts = [], zone = data.preferences.timezone;
  const motion = motionAllowed(data.preferences);
  const dateTick = new Intl.DateTimeFormat('tr-TR', { month: 'short', day: 'numeric', timeZone: zone });
  const timeTick = new Intl.DateTimeFormat('tr-TR', { hour: '2-digit', minute: '2-digit', timeZone: zone });
  const compact = new Intl.NumberFormat('tr-TR', { notation: 'compact', maximumFractionDigits: 1 });
  Chart.defaults.locale = 'tr-TR';
  Chart.defaults.color = muted;
  Chart.defaults.font.family = 'Segoe UI, system-ui, sans-serif';
  Chart.defaults.font.size = 10;

  function line(id, points, unit, paint, duration = 0, range) {
    const canvas = document.getElementById(id);
    if (!canvas || !points.length) return;
    const format = (v, axis = false) => axis ? compact.format(v) + (unit === 'money' ? '' : unit) : unit === 'R' ? r(v) : unit === '%' ? pct(v) : money(v, data);
    const gradient = context => {
      const area = context.chart.chartArea;
      if (!area) return paint + '18';
      const g = context.chart.ctx.createLinearGradient(0, area.top, 0, area.bottom);
      g.addColorStop(0, paint + '36');
      g.addColorStop(1, paint + '02');
      return g;
    };
    canvas.setAttribute('aria-label', 'Performans grafiği. Ok tuşlarıyla nokta seç, Enter ile kaynak işlemi aç.');
    charts.push(precisionChart(canvas, {
      points, duration: motion ? duration : 0, range, format,
      tick: value => (points.at(-1).date - points[0].date < 86400000 ? timeTick : dateTick).format(value),
      datasets: [{ data: points.map(p => ({ x: p.date, y: p.value })), borderColor: paint, backgroundColor: gradient, fill: 'origin', pointRadius: ({ dataIndex }) => dataIndex === points.length - 1 ? 3 : 0 }],
      describe: p => [format(p.value), shortDate(p.date, data, true),
        ...(p.trade ? [p.trade.instrument + ' · ' + money(net(p.trade), data) + ' · ' + r(p.trade.rMultiple)] : []),
        ...(p.drawdown != null ? ['ΣR ' + r(p.r) + ' · DD ' + money(p.drawdown, data)] : [])]
    }));
  }
  const ledger = ordered(rows);
  const points = rows.length ? curve(ledger).map((point, i) => ({ ...point, date: point.date ?? ledger[0].date, trade: ledger[i - 1] })) : [];
  const equity = points.map(p => ({ ...p, value: state.curveMode === 'R' ? p.r : state.curveMode === '%' ? p.equity / data.preferences.accountSize * 100 : p.equity }));
  if (document.getElementById('equity')) {
    line('equity', equity, state.curveMode === '$' ? 'money' : state.curveMode, equity.at(-1)?.value < 0 ? red : green, state.equityPresented ? 0 : 900);
    state.equityPresented = true;
  }
  line('cumulative-r', points.map(p => ({ ...p, value: p.r })), 'R', green);
  line('drawdown', points.map(p => ({ ...p, value: p.drawdown })), 'money', red);
  if (document.getElementById('rolling') || document.getElementById('quant-rolling')) {
    const rollingPoints = rolling(rows).map((p, i) => ({ ...p, trade: ledger[i] }));
    line('rolling', rollingPoints.map(p => ({ ...p, value: p.winRate })), '%', blue, 0, { min: 0, max: 100 });
    line('quant-rolling', rollingPoints.map(p => ({ ...p, value: p.expectancy })), 'money', green);
  }
  if (document.getElementById('account-curve')) {
    const closed = ordered(rows.filter(t => t.exitDate != null && t.exitDate <= Date.now()).map(t => ({ ...t, date: t.exitDate })));
    if (closed.length) line('account-curve', curve(closed).map((p, i) => ({ ...p, date: p.date ?? closed[0].date, value: p.equity, trade: closed[i - 1] })), 'money', green);
  }
  function bars(id, cohorts, key, label) {
    const canvas = document.getElementById(id);
    if (!canvas) return;
    charts.push(new Chart(canvas, { type: 'bar', data: { labels: cohorts.map(label), datasets: [{
      data: cohorts.map(g => g[key]), backgroundColor: cohorts.map(g => (g[key] < 0 ? red : green) + 'bc'), borderRadius: 4, maxBarThickness: 15
    }] }, options: { indexAxis: 'y', responsive: true, maintainAspectRatio: false, animation: false, plugins: { legend: { display: false }, tooltip: { callbacks: { afterLabel: ctx => 'n = ' + cohorts[ctx.dataIndex].count } } }, scales: { x: { beginAtZero: true, ...(key === 'winRate' ? { min: 0, max: 100 } : {}), grid: { color: muted + '19' }, border: { display: false } }, y: { grid: { display: false }, border: { display: false } } } } }));
  }
  if (document.getElementById('group-bars')) {
    const key = { 'Average R': 'averageR', 'Win rate': 'winRate', 'Net PnL': 'netPnL', Expectancy: 'expectancy', 'Profit factor': 'profitFactor' }[state.groupMetric];
    bars('group-bars', groups(rows, state.analysis, zone), key, g => ['Setup', 'Instrument'].includes(state.analysis) ? g.name : tr(g.name));
  }
  if (document.getElementById('research-bars')) bars('research-bars', researchGroups(rows, data, state).slice(0, 30), 'averageR', g => g.name);
  const scatter = document.getElementById('scatter-plot');
  if (scatter) {
    const points = scatterData(rows, state);
    charts.push(new Chart(scatter, { type: 'scatter', data: { datasets: [{
      data: points, pointBackgroundColor: points.map(p => compliant(p.trade) ? green : color('amber')),
      pointStyle: points.map(p => compliant(p.trade) ? 'circle' : 'rectRot'), pointRadius: points.map(p => p.trade.id === state.scatterID ? 7 : 4), pointHitRadius: 12
    }] }, options: {
      responsive: true, maintainAspectRatio: false, animation: false,
      onClick: (_, marks) => { if (marks.length) document.dispatchEvent(new CustomEvent('edge:scatter', { detail: points[marks[0].index].trade.id })); },
      plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => {
        const p = points[ctx.dataIndex];
        return [p.trade.instrument + ' · ' + shortDate(p.trade.date, data, true), n(p.x) + ' × ' + (state.scatterY === 'r' ? r(p.y) : money(p.y, data))];
      } } } }, scales: { x: { beginAtZero: true, ...(state.scatterX === 'process' ? { max: 100 } : {}), grid: { color: muted + '19' } }, y: { beginAtZero: true, grid: { color: muted + '19' } } }
    } }));
  }
  const outcomes = document.getElementById('quant-outcomes');
  if (outcomes) {
    charts.push(new Chart(outcomes, { type: 'bar', data: { labels: ledger.map((_, i) => i + 1), datasets: [{ data: ledger.map(net), backgroundColor: ledger.map(t => net(t) < 0 ? red : green), borderRadius: 3 }] }, options: {
      responsive: true, maintainAspectRatio: false, animation: false,
      onClick: (_, marks) => { if (marks.length) document.dispatchEvent(new CustomEvent('edge:trade', { detail: ledger[marks[0].index].id })); },
      plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => money(net(ledger[ctx.dataIndex]), data) } } },
      scales: { x: { grid: { display: false }, ticks: { maxTicksLimit: 10 } }, y: { beginAtZero: true, grid: { color: muted + '19' } } }
    } }));
  }
  const simulation = document.getElementById('simulation-chart');
  if (simulation && state.simulation) {
    const band = state.simulation.band;
    charts.push(precisionChart(simulation, {
      points: band.map(p => ({ ...p, date: p.id, value: p.median })),
      duration: motion && state.simulationReveal ? 650 : 0,
      format: (v, axis) => axis ? compact.format(v) : money(v, data), tick: value => Number.isInteger(value) ? value : '',
      describe: p => ['Medyan ' + money(p.median, data), 'Adım ' + p.id, '%5 ' + money(p.low, data) + ' · %95 ' + money(p.high, data)],
      datasets: [
        { data: band.map(p => ({ x: p.id, y: p.low })), borderColor: green + '40', borderWidth: 1 },
        { data: band.map(p => ({ x: p.id, y: p.high })), borderColor: green + '40', backgroundColor: green + '24', borderWidth: 1, fill: '-1' },
        { data: band.map(p => ({ x: p.id, y: p.median })), borderColor: green }
      ]
    }));
    state.simulationReveal = false;
  }
  if (document.getElementById('discipline-chart')) {
    const months = new Map();
    for (const t of rows) { const month = dateKey(t.date, zone).slice(0, 7); if (!months.has(month)) months.set(month, []); months.get(month).push(t); }
    line('discipline-chart', [...months].sort().map(([month, items]) => ({ date: Date.parse(month + '-15T12:00:00Z'), value: performance(items).compliance })), '%', green, 0, { min: 0, max: 100 });
  }
  return charts;
}
