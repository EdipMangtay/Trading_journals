import { z } from 'zod';
import Papa from 'papaparse';
import { t as translate } from './i18n.mjs';
import { legacyAccountID, normalizeWorkspace } from './workspace-state.mjs';

export const catalog = {
  sweeps: ['BSL Sweep', 'SSL Sweep', 'Equal Highs', 'Equal Lows', 'Previous Day High', 'Previous Day Low', 'Previous Week High', 'Previous Week Low', 'Session High', 'Session Low', 'Internal Liquidity', 'External Liquidity'],
  instruments: ['NQ', 'NASDAQ', 'US100', 'ES', 'SP500', 'XAUUSD', 'EURUSD', 'GBPUSD', 'US30'],
  sessions: ['Asia', 'London', 'NY AM', 'NY Lunch', 'NY PM'],
  timeframes: ['Monthly', 'Weekly', 'Daily', '4H', '1H', '15M', '5M', '3M', '1M'],
  liquidity: ['BSL', 'SSL', 'ERL', 'IRL', 'PDH', 'PDL', 'PWH', 'PWL', 'PMH', 'PML', 'EQH', 'EQL', 'Session High', 'Session Low', 'FVG', 'NWOG', 'NDOG'],
  confirmations: ['CISD', 'FVG', 'Inverse FVG', 'Order Block', 'Breaker', 'Market Structure Shift', 'Displacement', 'SMT', 'SSMT', 'CRT', 'OTE', 'Premium / Discount', 'Liquidity Sweep', 'Rejection', 'Opening Price', 'True Open'],
  rules: ['Entered before allowed session', 'No SSMT', 'No TSMO', 'No liquidity sweep', 'No HTF alignment', 'Wrong QT quarter', 'No displacement', 'Poor location', 'Chased entry', 'Early entry', 'Late entry', 'Overtrading', 'Revenge trade', 'FOMO', 'Oversized risk', 'Moved stop', 'Closed early', 'Ignored target', 'Pattern recognition override'],
  emotions: ['Calm', 'Confident', 'Focused', 'Hesitant', 'Fear', 'FOMO', 'Greed', 'Revenge', 'Frustrated', 'Overconfident', 'Impatient'],
  screenshotCategories: ['HTF', 'Before Entry', 'Entry', 'During Trade', 'Exit', 'Post Trade Review']
};
const string = z.string().max(100000);
const strings = z.array(string).max(1000);
const num = z.number().finite();
const optionalNumber = num.nullish();
const date = num.min(-8640000000000000).max(8640000000000000);
const bool = z.boolean();
const score = num.min(0).max(10);
const emotionScore = num.min(1).max(10);
const uuid = z.string().uuid();
const object = shape => z.object(shape).passthrough();
export const tradeSchema = object({
  id: uuid, date, exitDate: date.nullish(), instrument: string.trim().min(1), direction: z.enum(['Long', 'Short']), session: string,
  setupID: uuid.nullish(), setupName: string,
  entryPrice: optionalNumber, stopLoss: optionalNumber, takeProfit: optionalNumber, exitPrice: optionalNumber,
  positionSize: num.min(0).nullish(), riskDollars: num.min(0).nullish(), riskPercent: num.min(0).nullish(),
  grossPnL: num, fees: num.min(0), rMultiple: optionalNumber, bias: string, contextTimeframes: strings,
  drawOnLiquidity: string, liquidityTaken: strings, sweepValid: bool, htfAligned: bool,
  qt: object({ enabled: bool, higherQuarter: string, dailyQuarter: string, cycle90: string, cycle22: string, phase: string, trueOpen: bool, aligned: bool, valid: bool }),
  mmxm: object({ model: string, consolidation: bool, manipulation: bool, displacement: bool, repricing: bool, reversal: bool, target: bool, valid: bool }),
  po3: object({ phase: string, manipulationDirection: string, valid: bool }),
  ssmt: object({ confirmation: string, type: string, markets: strings, valid: bool }),
  crt: object({ enabled: bool, reentry: bool, confirmed: bool, timeframe: string, liquidityTaken: string, high: optionalNumber, low: optionalNumber }),
  tsmo: string, tsmoValid: bool, entryTimeframe: string, confirmations: strings,
  followsPlan: bool, brokenRules: strings, grade: z.enum(['A+', 'A', 'B', 'C', 'D', 'F']),
  scores: object({ marketRead: score, entry: score, compliance: score, risk: score, management: score, psychology: score, recognition: score }),
  emotional: object({ confidence: emotionScore, stress: emotionScore, fomo: emotionScore, focus: emotionScore, satisfaction: emotionScore, takeAgain: bool, emotions: strings }),
  notes: object({ thesis: string, entry: string, confirmation: string, invalidation: string, correct: string, incorrect: string, differently: string, lesson: string }), tags: strings
}).superRefine((t, ctx) => {
  const fail = message => ctx.addIssue({ code: 'custom', message });
  if (t.exitDate != null && t.exitDate < t.date) fail('Exit time must be after entry time.');
  if (t.crt.high != null && t.crt.low != null && t.crt.high < t.crt.low) fail('CRT range high must be above range low.');
  if (t.followsPlan && t.brokenRules.length) fail('Clear broken rules or mark this trade as outside your plan.');
  if (!t.followsPlan && !t.brokenRules.length) fail('Select at least one broken rule.');
});
const image = object({
  id: uuid, name: string, category: string,
  imageData: z.string().min(1).max(40000000), thumbnailData: z.string().min(1).max(40000000),
  annotations: z.array(object({ id: uuid, kind: string, x: num.min(0).max(1), y: num.min(0).max(1), endX: num.min(0).max(1), endY: num.min(0).max(1), text: string })).max(10000)
});
export const preferencesSchema = object({
  accountSize: num.positive(), defaultRiskPercent: num.min(0).max(100), currency: z.string().regex(/^[A-Z]{3}$/),
  theme: z.enum(['Dark', 'Light', 'System']), animations: bool,
  timezone: string.refine(value => { try { new Intl.DateTimeFormat('en', { timeZone: value }); return true; } catch { return false; } }, 'Invalid time zone.'),
  sessions: strings, sessionHours: z.record(z.string(), string)
});
export const backupSchema = object({
  version: z.union([z.literal(1), z.literal(2)]), createdAt: date, trades: z.array(tradeSchema).max(100000),
  screenshots: z.array(object({ tradeID: uuid, screenshot: image })).max(100000),
  setups: z.array(object({ id: uuid, name: string.trim().min(1), summary: string, playbookID: uuid, conditions: string, entry: string, invalidation: string, target: string, risk: string, images: z.array(image) })),
  reviews: z.array(object({ id: uuid, period: string, date, worked: string, didNot: string, repeatNext: string, stop: string, adjustment: string })),
  instruments: z.array(object({ id: uuid, symbol: string, enabled: bool })), rules: z.array(object({ id: uuid, name: string })), preferences: preferencesSchema
}).superRefine((b, ctx) => {
  const fail = message => ctx.addIssue({ code: 'custom', message });
  const idKey = value => value.toLowerCase();
  for (const [name, ids] of [
    ...['trades', 'setups', 'reviews', 'instruments', 'rules'].map(key => [key, b[key].map(x => idKey(x.id))]),
    ['screenshots', b.screenshots.map(x => idKey(x.screenshot.id))], ['playbooks', b.setups.map(x => idKey(x.playbookID))]
  ]) if (new Set(ids).size !== ids.length) fail(`Duplicate identifiers in ${name}.`);
  const trades = new Set(b.trades.map(t => idKey(t.id))), setups = new Set(b.setups.map(s => idKey(s.id)));
  if (b.trades.some(t => t.setupID && !setups.has(idKey(t.setupID)))) fail('A trade refers to a missing setup.');
  if (b.screenshots.some(s => !trades.has(idKey(s.tradeID)))) fail('A screenshot refers to a missing trade.');
});
export function parseBackup(value) {
  const result = backupSchema.safeParse(value);
  if (!result.success) throw new Error(result.error.issues.map(e => `${e.path.join('.')}: ${e.message}`).slice(0, 5).join('\n'));
  if (result.data.version === 2 && !result.data.workspace) throw new Error('V2 yedeğinin çalışma alanı eksik.');
  if (result.data.workspace) result.data.workspace = normalizeWorkspace(result.data.workspace, result.data.preferences, new Set(result.data.trades.map(t => t.id)));
  return result.data;
}
export function newTrade(id = crypto.randomUUID(), timestamp = Date.now()) {
  return {
    id, date: timestamp, instrument: 'NQ', direction: 'Long', session: 'NY AM', setupName: 'Unassigned', grossPnL: 0, fees: 0,
    bias: 'Neutral', contextTimeframes: [], drawOnLiquidity: '', liquidityTaken: [], sweepValid: false, htfAligned: false,
    qt: { enabled: false, higherQuarter: 'Q1', dailyQuarter: 'Q1', cycle90: 'Q1', cycle22: 'Q1', phase: 'Accumulation', trueOpen: false, aligned: false, valid: false },
    mmxm: { model: 'None', consolidation: false, manipulation: false, displacement: false, repricing: false, reversal: false, target: false, valid: false },
    po3: { phase: 'Accumulation', manipulationDirection: 'Up', valid: false },
    ssmt: { confirmation: 'Not Required', type: 'High divergence', markets: [], valid: false },
    crt: { enabled: false, reentry: false, confirmed: false, timeframe: '15M', liquidityTaken: 'High' },
    tsmo: 'Not Required', tsmoValid: false, entryTimeframe: '1M', confirmations: [], followsPlan: true, brokenRules: [], grade: 'B',
    scores: { marketRead: 5, entry: 5, compliance: 5, risk: 5, management: 5, psychology: 5, recognition: 5 },
    emotional: { confidence: 5, stress: 5, fomo: 1, focus: 5, satisfaction: 5, takeAgain: true, emotions: [] },
    notes: { thesis: '', entry: '', confirmation: '', invalidation: '', correct: '', incorrect: '', differently: '', lesson: '' }, tags: []
  };
}
export function emptyJournal() {
  return { version: 1, createdAt: Date.now(), trades: [], screenshots: [], setups: [], reviews: [], rules: [],
    instruments: catalog.instruments.map(symbol => ({ id: crypto.randomUUID(), symbol, enabled: true })),
    preferences: { accountSize: 50000, defaultRiskPercent: 0.5, currency: 'USD', theme: 'Dark', animations: true,
      timezone: 'America/New_York', sessions: [...catalog.sessions], sessionHours: { Asia: '20:00-00:00', London: '02:00-05:00', 'NY AM': '09:30-11:00', 'NY Lunch': '11:00-13:00', 'NY PM': '13:00-16:00' } }
  };
}
export const net = t => t.grossPnL - t.fees;
export const compliant = t => t.followsPlan && !t.brokenRules.length;
export const classification = t => Math.abs(net(t)) < 0.005 ? 'BREAKEVEN' : `${compliant(t) ? 'VALID' : 'INVALID'} ${net(t) > 0 ? 'WINNER' : 'LOSER'}`;
export const execution = t => ['marketRead', 'entry', 'compliance', 'risk', 'management', 'psychology', 'recognition'].reduce((sum, key) => sum + t.scores[key], 0) / 7 * 10;
export const flags = t => ({ QT: t.qt.enabled && t.qt.valid && t.qt.aligned, MMXM: t.mmxm.model !== 'None' && t.mmxm.valid, SSMT: t.ssmt.confirmation === 'Yes' && t.ssmt.valid, TSMO: t.tsmo === 'Yes' && t.tsmoValid, CRT: t.crt.enabled && t.crt.confirmed });
export const ordered = trades => [...trades].sort((a, b) => a.date - b.date || a.id.localeCompare(b.id));
export function performance(trades) {
  const p = { count: trades.length, wins: 0, losses: 0, netPnL: 0, totalR: 0, rCount: 0, grossProfit: 0, grossLoss: 0, maxDrawdown: 0, compliance: 0, executionScore: 0, currentWinStreak: 0, currentLossStreak: 0, longestWinStreak: 0, longestLossStreak: 0, bestTrade: 0, worstTrade: 0 };
  let peak = 0, durations = [], winningR = [];
  for (const t of ordered(trades)) {
    const n = net(t); p.netPnL += n;
    if (n >= 0.005) { p.wins++; p.grossProfit += n; p.currentWinStreak++; p.currentLossStreak = 0; if (t.rMultiple != null) winningR.push(t.rMultiple); }
    else if (n <= -0.005) { p.losses++; p.grossLoss -= n; p.currentLossStreak++; p.currentWinStreak = 0; }
    else { p.currentLossStreak = 0; p.currentWinStreak = 0; }
    p.longestWinStreak = Math.max(p.longestWinStreak, p.currentWinStreak); p.longestLossStreak = Math.max(p.longestLossStreak, p.currentLossStreak);
    if (t.rMultiple != null) { p.totalR += t.rMultiple; p.rCount++; }
    peak = Math.max(peak, p.netPnL); p.maxDrawdown = Math.max(p.maxDrawdown, peak - p.netPnL);
    p.compliance += compliant(t) ? 1 : 0; p.executionScore += execution(t);
    if (t.exitDate != null && t.exitDate >= t.date) durations.push((t.exitDate - t.date) / 1000);
  }
  p.winRate = p.count ? p.wins / p.count * 100 : 0;
  p.lossRate = p.count ? p.losses / p.count * 100 : 0;
  p.profitFactor = p.grossLoss ? p.grossProfit / p.grossLoss : null;
  p.expectancy = p.count ? p.netPnL / p.count : 0;
  p.averageR = p.rCount ? p.totalR / p.rCount : null;
  p.averageWinner = p.wins ? p.grossProfit / p.wins : 0;
  p.averageLoser = p.losses ? -p.grossLoss / p.losses : 0;
  p.compliance = p.count ? p.compliance / p.count * 100 : 0;
  p.executionScore = p.count ? p.executionScore / p.count : 0;
  p.bestTrade = p.count ? trades.reduce((best, t) => Math.max(best, net(t)), -Infinity) : 0; p.worstTrade = p.count ? trades.reduce((worst, t) => Math.min(worst, net(t)), Infinity) : 0;
  p.averageDuration = durations.length ? durations.reduce((a, b) => a + b, 0) / durations.length : null;
  p.averageWinningR = winningR.length ? winningR.reduce((a, b) => a + b, 0) / winningR.length : null;
  p.recoveryFactor = p.maxDrawdown ? p.netPnL / p.maxDrawdown : null;
  p.payoffRatio = p.averageLoser < 0 ? p.averageWinner / Math.abs(p.averageLoser) : null;
  const aPlus = trades.filter(t => t.grade === 'A+'); p.aPlusWinRate = aPlus.length ? aPlus.filter(t => net(t) >= 0.005).length / aPlus.length * 100 : null;
  return p;
}
export function curve(trades) {
  let equity = 0, r = 0, peak = 0;
  return [{ equity: 0, r: 0, drawdown: 0 }, ...ordered(trades).map(t => {
    equity += net(t); r += t.rMultiple ?? 0; peak = Math.max(peak, equity);
    return { date: t.date, equity, r, drawdown: equity - peak };
  })];
}
export function dateKey(timestamp, timezone) {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(timestamp);
  const part = type => parts.find(p => p.type === type).value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}
export function wallTime(timestamp, timezone) {
  if (timestamp == null) return '';
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(timestamp);
  const get = type => parts.find(p => p.type === type).value;
  return `${get('year')}-${get('month')}-${get('day')}T${get('hour')}:${get('minute')}`;
}
export function instantFromWallTime(value, timezone) {
  const target = Date.parse(value + ':00Z');
  if (!Number.isFinite(target)) throw new Error('Geçerli bir tarih ve saat gir.');
  let stamp = target;
  // Intl supplies zone rules; resolve the corresponding instant, including DST offsets.
  for (let i = 0; i < 4; i++) {
    const displayed = wallTime(stamp, timezone);
    if (displayed === value) return stamp;
    stamp += target - Date.parse(displayed + ':00Z');
  }
  throw new Error('Bu saat, seçilen saat diliminde yaz saati geçişi nedeniyle yok. Başka bir saat seç.');
}
export function groups(trades, dimension, timezone = 'America/New_York') {
  const buckets = new Map();
  for (const t of trades) {
    const f = flags(t);
    const values = {
      Setup: [t.setupName], Instrument: [t.instrument], Session: [t.session], Direction: [t.direction], Grade: [t.grade],
      'Day of week': [new Intl.DateTimeFormat('en', { weekday: 'long', timeZone: timezone }).format(t.date)],
      Hour: [new Intl.DateTimeFormat('en-GB', { hour: '2-digit', hourCycle: 'h23', timeZone: timezone }).format(t.date) + ':00'],
      'QT quarter': [t.qt.enabled ? t.qt.dailyQuarter : 'No QT'], MMXM: [t.mmxm.model],
      SSMT: [f.SSMT ? 'Valid SSMT' : 'Without valid SSMT'], TSMO: [f.TSMO ? 'Valid TSMO' : 'Without valid TSMO'], CRT: [f.CRT ? 'Confirmed CRT' : 'Without confirmed CRT'],
      'Liquidity taken': t.liquidityTaken.length ? t.liquidityTaken : ['Unspecified'], 'HTF alignment': [t.htfAligned ? 'Aligned' : 'Not aligned'],
      'Entry timeframe': [t.entryTimeframe], 'Rule compliance': [compliant(t) ? 'Fully valid' : 'Rule break'],
      Emotion: t.emotional.emotions.length ? t.emotional.emotions : ['Unspecified'], Classification: [classification(t)],
      'QT validity': [f.QT ? 'Valid & aligned' : 'Not valid / aligned'], 'Draw on liquidity': [t.drawOnLiquidity || 'Unspecified'],
      Mistakes: t.brokenRules
    };
    for (const key of new Set(values[dimension] || [t.setupName])) { if (!buckets.has(key)) buckets.set(key, []); buckets.get(key).push(t); }
  }
  return [...buckets].map(([name, rows]) => ({ name, ...performance(rows) })).sort((a, b) => a.name.localeCompare(b.name));
}
export function mergeBackup(current, incoming) {
  current = parseBackup(current); incoming = parseBackup(incoming);
  const merged = { ...current, createdAt: Date.now(), preferences: incoming.preferences };
  for (const key of ['trades', 'setups', 'reviews', 'instruments', 'rules']) {
    const byID = new Map(current[key].map(item => [item.id.toLowerCase(), item]));
    incoming[key].forEach(item => byID.set(item.id.toLowerCase(), item)); merged[key] = [...byID.values()];
  }
  const changed = new Set(incoming.trades.map(t => t.id.toLowerCase()));
  merged.screenshots = [...current.screenshots.filter(s => !changed.has(s.tradeID.toLowerCase())), ...incoming.screenshots];
  if (incoming.workspace) {
    const previous = normalizeWorkspace(current.workspace, current.preferences);
    const next = { ...previous, ...incoming.workspace };
    for (const key of ['accounts', 'presets', 'templates', 'plans']) {
      next[key] = [...new Map([...previous[key], ...incoming.workspace[key]].map(item => [item.id.toLowerCase(), item])).values()];
    }
    next.assignments = { ...previous.assignments, ...incoming.workspace.assignments };
    next.supplements = { ...previous.supplements, ...incoming.workspace.supplements };
    merged.workspace = next;
    merged.version = 2;
  } else if (merged.workspace) {
    const legacy = merged.workspace.accounts.find(account => account.id === legacyAccountID);
    legacy.currency = incoming.preferences.currency;
    legacy.startingBalance = incoming.preferences.accountSize;
  }
  return parseBackup(merged);
}
export function exportCSV(trades) {
  return Papa.unparse(trades.map(t => ({ id: t.id, date: new Date(t.date).toISOString(), instrument: t.instrument, direction: t.direction, session: t.session,
    setup: t.setupName, gross_pnl: t.grossPnL, fees: t.fees, net_pnl: net(t), r_multiple: t.rMultiple ?? '', risk_dollars: t.riskDollars ?? '', grade: t.grade,
    follows_plan: t.followsPlan, broken_rules: t.brokenRules.join(' | '), classification: classification(t), notes: t.notes.thesis, record_json: JSON.stringify(t)
  })), { header: true, quotes: true, escapeFormulae: /^[=+\-@\t\r]/ });
}
export function importCSV(text, setups = [], { allowDuplicateIDs = false } = {}) {
  const parsed = Papa.parse(text, { header: true, skipEmptyLines: 'greedy', transformHeader: h => h.trim().toLowerCase().replace(/^\uFEFF/, '') });
  if (parsed.errors.length || Object.keys(parsed.meta.renamedHeaders || {}).length) throw new Error('CSV has malformed rows or duplicate columns.');
  const records = parsed.data.map((row, index) => {
    let trade;
    if (row.record_json) trade = JSON.parse(row.record_json);
    else {
      if (!row.instrument || !row.date || !row.gross_pnl?.trim()) throw new Error(`Row ${index + 2}: instrument, ISO date and gross_pnl are required.`);
      trade = newTrade(row.id || crypto.randomUUID(), Date.parse(row.date));
      Object.assign(trade, { instrument: row.instrument, grossPnL: Number(row.gross_pnl), direction: row.direction || 'Long', session: row.session || 'NY AM', setupName: row.setup || 'Unassigned', grade: row.grade || 'B', followsPlan: row.follows_plan?.toLowerCase() !== 'false', brokenRules: (row.broken_rules || '').split(' | ').filter(Boolean) });
      for (const [column, field] of [['fees', 'fees'], ['r_multiple', 'rMultiple'], ['risk_dollars', 'riskDollars']]) if (row[column]?.trim()) trade[field] = Number(row[column]);
      trade.notes.thesis = row.notes || '';
    }
    const setup = setups.find(s => s.id.toLowerCase() === trade.setupID?.toLowerCase() || s.name === trade.setupName);
    if (setup) { trade.setupID = setup.id; trade.setupName = setup.name; } else delete trade.setupID;
    return tradeSchema.parse(trade);
  });
  if (!records.length) throw new Error('CSV contains no trades.');
  if (!allowDuplicateIDs && new Set(records.map(t => t.id.toLowerCase())).size !== records.length) throw new Error('Duplicate trade identifiers.');
  return records;
}

export function matchesSearch(trade, query) {
  const normalize = value => value.toLowerCase().replaceAll('ı', 'i').normalize('NFD').replace(/\p{M}/gu, '');
  let tokens = normalize(query.trim()).split(/\s+/).filter(Boolean);
  const f = flags(trade), type = classification(trade);
  const special = [
    ['kuralsiz kazanc', type === 'INVALID WINNER'], ['kuralsiz zarar', type === 'INVALID LOSER'], ['kuralli kazanc', type === 'VALID WINNER'], ['kuralli zarar', type === 'VALID LOSER'],
    ['yalniz crt', f.CRT && !f.SSMT && !f.TSMO && !f.QT && !f.MMXM], ['ssmt yok', !f.SSMT], ['tsmo yok', !f.TSMO],
    ['kuralli', compliant(trade)], ['kuralsiz', !compliant(trade)], ['kazanc', net(trade) >= .005], ['zarar', net(trade) <= -.005],
    ['invalid winner', type === 'INVALID WINNER'], ['invalid loser', type === 'INVALID LOSER'], ['valid winner', type === 'VALID WINNER'], ['valid loser', type === 'VALID LOSER'],
    ['crt only', f.CRT && !f.SSMT && !f.TSMO && !f.QT && !f.MMXM], ['no ssmt', !f.SSMT], ['no tsmo', !f.TSMO], ['ssmt', f.SSMT], ['tsmo', f.TSMO],
    ['crt', f.CRT], ['qt', trade.qt.enabled], ['mmxm', trade.mmxm.model !== 'None'], ['loser', net(trade) <= -.005], ['winner', net(trade) >= .005]
  ];
  for (const [phrase, match] of special) {
    const words = phrase.split(' '), index = tokens.findIndex((_, i) => words.every((word, j) => tokens[i + j] === word));
    if (index >= 0) { if (!match) return false; tokens.splice(index, words.length); }
  }
  const localized = [trade.direction, trade.session, type, ...trade.brokenRules, ...trade.confirmations, ...trade.emotional.emotions].map(translate);
  const haystack = normalize([trade.instrument, trade.instrument.toUpperCase() === 'XAUUSD' ? 'gold altin' : '', trade.direction, trade.session, trade.setupName, trade.grade, trade.qt.dailyQuarter, trade.qt.higherQuarter, trade.entryTimeframe, trade.drawOnLiquidity, trade.notes.thesis, trade.notes.lesson, type, ...trade.tags, ...trade.brokenRules, ...trade.confirmations, ...trade.emotional.emotions, ...localized].join(' '));
  return tokens.every(token => haystack.includes(token));
}

export function periodRange(timestamp, period, timezone) {
  const day = dateKey(timestamp, timezone), date = new Date(day + 'T12:00:00Z');
  if (period === 'Weekly' || period === 'THIS WEEK') { const offset = (date.getUTCDay() + 6) % 7; date.setUTCDate(date.getUTCDate() - offset); }
  else if (period === 'Monthly' || period === 'THIS MONTH') date.setUTCDate(1);
  const from = date.toISOString().slice(0, 10);
  if (period === 'Weekly' || period === 'THIS WEEK') date.setUTCDate(date.getUTCDate() + 6);
  else if (period === 'Monthly' || period === 'THIS MONTH') date.setUTCMonth(date.getUTCMonth() + 1, 0);
  return { from, to: date.toISOString().slice(0, 10) };
}

export function correlation(points) {
  if (points.length < 3) return null;
  const mx = points.reduce((sum, p) => sum + p[0], 0) / points.length, my = points.reduce((sum, p) => sum + p[1], 0) / points.length;
  const numerator = points.reduce((sum, [x,y]) => sum + (x-mx)*(y-my), 0);
  const denominator = Math.sqrt(points.reduce((sum,[x])=>sum+(x-mx)**2,0)*points.reduce((sum,[,y])=>sum+(y-my)**2,0));
  return denominator ? numerator / denominator : null;
}
