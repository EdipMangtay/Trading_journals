import { performance, net, groups, dateKey, instantFromWallTime, wallTime, compliant, execution, correlation } from '../shared/core.mjs';
import { accountFor, selectedAccount } from '../shared/workspace-state.mjs';
import { riskSnapshot, percentile, underwater } from '../shared/workstation.mjs';
import { esc, header, panel, metric, field, note, pick, options, toggle, command, chart, filterBar, groupTable, tradeRows, money, pct, r, shortDate, dimensions, empty } from './views.js';

export function accountPicker(data) {
  return `<select id="account-picker" aria-label="Hesap" title="Performans ekranları seçili hesaba göre filtrelenir">${options(data.workspace.accounts.map(a => [a.id, a.name]), data.workspace.selectedAccountID, undefined, false)}</select>`;
}

const number = (name, label, value, step = 'any') => field(name, label, value, 'number', `step="${step}"`);
const cash = (value, data) => value == null ? '—' : money(value, data);
const line = (label, value) => `<div class="line risk-row"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>`;
const meter = (label, value, total, detail) => `<div class="risk-meter">${line(label, detail)}<progress aria-label="${esc(label)}" max="1" value="${Math.max(0, Math.min(1, value / total))}"></progress></div>`;
export const riskFields = [['profitTarget', 'Kâr hedefi'], ['dailyLoss', 'Günlük kayıp sınırı'], ['maximumLoss', 'Maksimum kayıp'], ['minimumDays', 'Minimum işlem günü', '1'], ['consistencyPercent', 'Tutarlılık üst sınırı %'], ['riskPerTrade', 'İşlem başına risk sınırı'], ['dailyTradeCount', 'Günlük işlem adedi', '1']];

export function accountsPage(data, rows, allData) {
  const account = selectedAccount(data), rules = account.rules;
  const risk = riskSnapshot(rows, account, data.preferences.timezone);
  return header('ACCOUNTS / RISK', 'Sermayeni tanı. Sınırlarını izle.', 'Kayıtlı kapanışlar üzerinden hesap bazlı risk değerlendirmesi.', command('new-account', 'Hesap ekle', 'plus', 'class="primary"')) +
    `<div class="line">${accountPicker(data).replace('id="account-picker"', 'data-account-picker')}${command('edit-account', 'Hesabı ve kuralları düzenle', 'sliders-horizontal')}</div>
      <div class="metrics terminal-metrics">${metric('KAYITLI BAKİYE', money(risk.balance, data))}${metric('GERÇEKLEŞEN NET', money(risk.realized, data), '', risk.realized < 0 ? 'negative' : 'positive')}${metric('KAYIP SINIRINA MESAFE', cash(risk.remaining, data))}${metric('İŞLEM GÜNÜ', `${risk.days} / ${rules.minimumDays ?? '—'}`)}</div>` +
    (risk.unverified ? '<p class="warning">Doğrulanamadı. Çıkış zamanı eksik veya kural gün içi equity verisi gerektiriyor.</p>' : '') +
    (risk.historicalBreach ? '<p class="negative">Kayıtlı kapanışlarda tanımlı kayıp sınırı aşıldı.</p>' : '') +
    `<div class="risk-grid">${panel('HESAP PERFORMANSI', rows.some(t => t.exitDate != null && t.exitDate <= Date.now()) ? chart('account-curve', 280) : empty('Kapanış kaydı yok.', 'Bakiye grafiği için işlemlerinin çıkış zamanını kaydet.'), 'Çıkış zamanına göre gerçekleşen net sonuç')}
    ${panel('KURAL PANOSU',
      (rules.profitTarget ? meter('Kâr hedefine ilerleme', risk.realized, rules.profitTarget, pct(risk.realized / rules.profitTarget * 100)) : '') +
      (rules.maximumLoss && risk.remaining != null ? meter('Kayıp payı kullanımı', rules.maximumLoss - risk.remaining, rules.maximumLoss, cash(risk.remaining, data) + ' kalan') : '') +
      (rules.minimumDays ? meter('İşlem günleri', risk.days, rules.minimumDays, `${risk.days} / ${rules.minimumDays}`) : '') +
      line('Bugünkü net sonuç', cash(risk.today, data)) + line('Günlük kalan pay', cash(risk.dailyRemaining, data)) +
      line('Drawdown yöntemi', rules.drawdownMethod) + line('Bakiye alt sınırı', cash(risk.floor, data)) +
      line('Bugünkü giriş sayısı', `${risk.todayCount} / ${rules.dailyTradeCount ?? '—'}`) +
      line('En iyi gün / toplam kâr', risk.consistency == null ? '—' : pct(risk.consistency)) +
      (rules.consistencyPercent ? line('Tutarlılık üst sınırı', pct(rules.consistencyPercent) + (risk.consistency > rules.consistencyPercent ? ' · Aşıldı' : '')) : '') +
      line('Risk miktarı sınır aşımı', risk.oversizedTrades) + line('Günlük sayı sınır aşımı', risk.dailyCountBreaches))}</div>` +
    panel('HESAPLARI KARŞILAŞTIR', data.workspace.accounts.map(a => {
      const p = performance(allData.trades.filter(t => accountFor(allData, t.id) === a.id));
      return line(a.name, `n = ${p.count} · ${r(p.averageR)} · ${money(p.netPnL, { preferences: { currency: a.currency } })}`);
    }).join(''), 'Para birimleri ayrı tutulur.');
}

const dialog = (id, title, body, label = 'Kaydet') => `<form id="${id}"><header><h2>${title}</h2>${command('close-editor', 'Kapat', 'x')}</header><div class="body">${body}<p id="form-error" class="error" role="alert"></p></div><footer class="footer">${command('close-editor', 'Vazgeç')}<button class="primary" type="submit">${label}</button></footer></form>`;
export function accountEditor(a) {
  return dialog('account-form', 'Hesap ve risk kuralları',
    `<div class="form-grid">${field('name', 'Hesap adı', a.name, 'text', 'required')}${field('currency', 'Para birimi', a.currency, 'text', 'required maxlength="3" pattern="[A-Za-z]{3}"')}${number('startingBalance', 'Başlangıç bakiyesi', a.startingBalance)}${field('category', 'Hesap türü / firma', a.category)}${pick('drawdownMethod', 'Drawdown yöntemi', ['Static', 'End of day', 'Intraday equity'], a.rules.drawdownMethod ?? 'Static')}</div>
    ${toggle('active', 'Aktif hesap', a.active)}<div class="form-grid">${riskFields.map(([key, label, step]) => number(key, label, a.rules[key], step)).join('')}</div>`, 'Hesabı kaydet');
}

export function researchGroups(rows, data, state) {
  const buckets = new Map(), zone = data.preferences.timezone;
  for (const trade of rows) {
    for (const left of groups([trade], state.researchFirst, zone)) for (const right of groups([trade], state.researchSecond, zone)) {
      const name = left.name + ' × ' + right.name;
      if (!buckets.has(name)) buckets.set(name, []);
      buckets.get(name).push(trade);
    }
  }
  return [...buckets].sort(([a], [b]) => a.localeCompare(b)).map(([name, trades]) => ({ name, trades, ...performance(trades) }));
}

export function scatterData(rows, state) {
  const x = { process: execution, risk: t => t.riskPercent, duration: t => t.exitDate == null ? null : (t.exitDate - t.date) / 60000 }[state.scatterX];
  const y = state.scatterY === 'r' ? t => t.rMultiple : net;
  return rows.map(trade => ({ trade, x: x(trade), y: y(trade) })).filter(p => Number.isFinite(p.x) && Number.isFinite(p.y));
}

export function scatterPanel(rows, data, state) {
  const points = scatterData(rows, state), selected = points.find(p => p.trade.id === state.scatterID);
  const association = correlation(points.map(p => [p.x, p.y]));
  return panel('Dağılım analizi',
    `<div class="actions scatter-pickers">${pick('scatterX', 'Yatay eksen', [['process', 'Süreç puanı'], ['risk', 'Risk (%)'], ['duration', 'İşlem süresi']], state.scatterX)}${pick('scatterY', 'Dikey eksen', [['r', 'Sonuç (R)'], ['pnl', 'Net K/Z']], state.scatterY)}</div>
    <div class="plot-selection">${selected ? `<strong>${esc(selected.trade.instrument)} · ${shortDate(selected.trade.date, data, true)}</strong><span>${state.scatterY === 'r' ? r(selected.y) : money(selected.y, data)}</span>${command('open-source', 'İşleme git', 'arrow-up-right', `data-id="${selected.trade.id}"`)}` : 'Bir nokta seçerek kaynak işlemi incele.'}</div>
    ${points.length ? chart('scatter-plot', 310) : '<p class="muted">Seçili iki eksen için kayıt bulunamadı.</p>'}
    ${pick('scatterID', 'İşlemi klavyeyle incele', points.slice(0, 2000).map(p => [p.trade.id, p.trade.instrument + ' · ' + shortDate(p.trade.date, data, true)]), state.scatterID, 'Nokta seç')}
    <div class="line caption"><span>● Plana uygun · ◆ Kural ihlali</span><span>${points.length} / ${rows.length} gözlem · Pearson r ${association == null ? '—' : association.toFixed(2)}</span></div>
    <p class="caption">Her nokta bir işlemdir. İlişki, nedensellik veya gelecekteki sonuç anlamına gelmez.</p>`, 'Süreç, risk ve süreyi sonuçlarla karşılaştır');
}

export function researchPage(data, state, rows, applyPreset) {
  const cohorts = researchGroups(rows, data, state), selected = cohorts.find(c => c.name === state.cohort);
  const p = performance(rows), presets = data.workspace.presets.map(preset => [preset.id, preset.name]);
  const compare = data.workspace.presets.find(item => item.id === state.comparePreset);
  const comparison = compare ? applyPreset(compare) : [];
  const monthly = new Map();
  for (const trade of rows) {
    const key = dateKey(trade.date, data.preferences.timezone).slice(0, 7);
    if (!monthly.has(key)) monthly.set(key, []);
    monthly.get(key).push(trade);
  }
  const monthlyRows = [...monthly].sort().map(([name, trades]) => ({ name, ...performance(trades) }));
  return header('RESEARCH / COHORTS', 'Sorunu seç. Kanıtı incele.', 'Kayıtlı strateji ve teyitleri çok boyutlu karşılaştır.') + filterBar(data, state) +
    `<form id="preset-form" class="actions">${field('presetName', 'Araştırmaya ad ver', '', 'text', 'required maxlength="100"')}<button type="submit">Filtreyi kaydet</button>${pick('loadPreset', 'Kayıtlı araştırmalar', presets, state.loadedPreset, 'Filtre seç')}${state.loadedPreset ? command('delete-preset', 'Filtreyi sil', 'trash-2') : ''}</form>
    <div class="metrics terminal-metrics">${metric('GÖZLEM', 'n = ' + p.count)}${metric('ORTALAMA R', r(p.averageR))}${metric('UYUM', pct(p.compliance))}${metric('BEKLENTİ / İŞLEM', money(p.expectancy, data))}</div>
    <p class="caption warning">Örneklem 30’un altındaysa bulgu sınırlıdır. Kohortlar örtüşebilir.</p>` +
    panel('ÇAPRAZ ARAŞTIRMA',
      `<div class="actions">${pick('researchFirst', 'İlk boyut', dimensions, state.researchFirst)}${pick('researchSecond', 'İkinci boyut', dimensions, state.researchSecond)}</div>
      ${cohorts.length ? chart('research-bars', Math.min(740, Math.max(160, cohorts.length * 30))) : '<p class="muted">Bu filtrede kayıt yok.</p>'}
      ${cohorts.length > 30 ? '<p class="caption">Grafikte ilk 30 kohort gösterilir. Tüm kohortlar aşağıda.</p>' : ''}
      <div class="cohort-list">${cohorts.map(c => `<button type="button" class="line ${selected === c ? 'selected' : ''}" data-cohort="${esc(c.name)}"><span>${esc(c.name)}</span><small>n = ${c.count}</small><strong>${r(c.averageR)}</strong></button>`).join('')}</div>`) +
    (selected ? panel(esc(selected.name), tradeRows(selected.trades, data), selected.count + ' kaynak işlem') : '') +
    panel('KOHORT A / KOHORT B', pick('comparePreset', 'B kohortu', presets, state.comparePreset, 'Kayıtlı filtre seç') +
      (compare ? groupTable([{ name: 'A / mevcut filtre', ...p }, { name: 'B / ' + compare.name, ...performance(comparison) }], data) : ''), 'A mevcut filtreyi, B kayıtlı filtreyi kullanır.') +
    scatterPanel(rows, data, state) +
    (monthlyRows.length ? panel('STRATEJİ / AYLIK İSTİKRAR', groupTable(monthlyRows, data), 'Aylık sonuçlar ve örneklem büyüklüğü') : '');
}

export function quantPage(data, state, rows) {
  const p = performance(rows), under = underwater(rows), s = state.simulation;
  return header('QUANT / SCENARIOS', 'Olasılıkları gör. Belirsizliği koru.', 'Geçmiş kayıtları ve tekrar örneklenen senaryoları ayrı incele.') +
    `<div class="metrics terminal-metrics">${metric('GÖZLEM', 'n = ' + p.count)}${metric('BEKLENTİ', money(p.expectancy, data))}${metric('MAKS. DÜŞÜŞ', money(p.maxDrawdown, data))}${metric('ZİRVE ALTINDA', (under.longestSeconds / 86400).toFixed(1) + ' gün', under.ongoing ? 'Toparlanma sürüyor' : '')}</div>` +
    (rows.length ? panel('HAREKETLİ ÖLÇÜMLER', chart('quant-rolling', 220), 'Son 20 kayıt üzerinden net beklenti') : '') +
    (rows.length ? panel('SONUÇ DAĞILIMI', chart('quant-outcomes', 175), 'Her sütun bir işlem · zaman sırası korunur') : '') +
    panel('MONTE CARLO', `<form id="simulation-form" class="actions">${pick('shuffle', 'Yöntem', [['false', 'Yerine koyarak örnekle'], ['true', 'İşlem sırasını karıştır']], String(state.shuffle))}
      ${field('horizon', 'Ufuk (işlem)', state.horizon, 'number', 'min="10" max="1000" step="10" required')}
      <button type="submit" class="primary" ${rows.length < 2 || state.simulating ? 'disabled' : ''}>${state.simulating ? 'Hesaplanıyor…' : 'Senaryoları hesapla'}</button>${state.simulating ? '<span class="spinner" role="status" aria-label="Senaryo hesabı sürüyor"></span>' : ''}</form>` +
      (s ? chart('simulation-chart', 320) + `<div class="metrics terminal-metrics">${metric('ZARARLA BİTEN', pct(s.lossFraction * 100))}${metric('MEDYAN MAKS. DÜŞÜŞ', money(percentile(s.drawdowns, .5), data))}${metric('SENARYOLAR', s.runs)}${metric('UFUK', s.horizon + ' işlem')}</div>` : '<p class="caption">En az iki işlemle hesaplanır.</p>') +
      '<p class="caption">Bant %5–%95 senaryo yüzdeliklerini, çizgi medyanı gösterir. Simülasyon sonuçları geçmiş kayıtların kendisi değildir.</p>') +
    panel('ARDIŞIK KAYIP / VARSAYIM', `<div class="actions">${field('scenarioRisk', 'Kayıp başına tutar', state.scenarioRisk ?? 250, 'number', 'min="0" step="any"')}${field('scenarioLosses', 'Kayıp sayısı', state.scenarioLosses ?? 5, 'number', 'min="1" max="50" step="1"')}<output>${money((state.scenarioRisk ?? 250) * (state.scenarioLosses ?? 5), data)}</output></div>`, 'Varsayımsal toplam kayıp');
}

export const planFields = [['scenarios', 'Piyasa senaryoları'], ['instruments', 'Enstrümanlar'], ['liquidity', 'Önemli likidite seviyeleri'], ['focus', 'Strateji odağı'], ['limits', 'Risk sınırları'], ['objectives', 'Seans hedefleri']];
export function planningPage(data, state, rows) {
  const date = state.planDate || dateKey(Date.now(), data.preferences.timezone);
  const plan = data.workspace.plans.find(p => p.accountID.toLowerCase() === data.workspace.selectedAccountID && dateKey(p.date, data.preferences.timezone) === date);
  return header('PREPARE / EXECUTE / REVIEW', 'Seansa bir planla başla.', 'Günlük hazırlığını kaydet ve gerçekleşen işlemlerle birlikte incele.') +
    panel('SEANS HAZIRLIĞI', `${field('planDate', 'Gün', date, 'date')}<form id="plan-form"><div class="form-grid two">${planFields.map(([key, label]) => note(key, label, state.planDraft?.[key] ?? plan?.[key])).join('')}</div><button type="submit" class="primary">Günlük planı kaydet</button></form>`, esc(selectedAccount(data).name)) +
    panel('GÜNÜN İŞLEMLERİ', tradeRows(rows.filter(t => dateKey(t.date, data.preferences.timezone) === date), data));
}

export function executionEditor(trade, supplement, data) {
  const fillRows = supplement.fills.map((f, i) => `<div class="fill-row" data-fill="${i}"><div class="form-grid">
    ${field('date', 'Zaman', wallTime(f.date, data.preferences.timezone), 'datetime-local', 'required')}
    ${pick('side', 'Taraf', [['Entry', 'Giriş'], ['Exit', 'Çıkış']], f.side)}
    ${number('quantity', 'Miktar', f.quantity)}${number('price', 'Fiyat', f.price)}${number('fee', 'Masraf', f.fee)}${number('expectedPrice', 'Beklenen fiyat', f.expectedPrice)}</div>${command('remove-fill', 'Satırı kaldır', 'minus', `data-index="${i}"`)}</div>`).join('');
  const checklist = supplement.checklist.map((item, i) => `<div class="actions checklist-row" data-checklist="${i}">
    ${field('label', 'Kontrol maddesi', item.label, 'text', 'required')}${pick('phase', 'Aşama', ['Öncesi', 'Sırası', 'Sonrası'], item.phase)}
    ${pick('answer', 'Yanıt', [['true', 'Evet'], ['false', 'Hayır']], item.answer == null ? '' : String(item.answer), 'Yanıt yok')}
    ${command('remove-check', 'Maddeyi kaldır', 'minus', `data-index="${i}"`)}</div>`).join('');
  return dialog('execution-form', 'Gerçekleşmeler ve kontrol listesi',
    `<p class="caption">${esc(trade.instrument)} · Kaydedilen K/Z, açıkça uygulanmadıkça değişmez.</p>
    <div class="form-grid two">${number('pointValue', 'Puan değeri', supplement.pointValue)}${number('tickSize', 'Tick boyutu', supplement.tickSize)}</div>
    ${panel('GERÇEKLEŞMELER', fillRows + command('add-fill', 'Gerçekleşme ekle', 'plus') + command('preview-execution', 'Gerçekleşme hesabı') + '<output id="execution-preview"></output>')}
    ${panel('KONTROL LİSTESİ', checklist + command('add-check', 'Madde ekle', 'plus') + pick('checklistTemplate', 'Şablon', data.workspace.templates.map(t => [t.id, t.name]), '', 'Şablon seç') + field('templateName', 'Şablon adı') + command('save-template', 'Şablon olarak kaydet'))}
    <label class="check"><input type="checkbox" name="applyPnL">Kapalı gerçekleşmelerden net K/Z uygula</label>`, 'Gerçekleşmeleri kaydet');
}
