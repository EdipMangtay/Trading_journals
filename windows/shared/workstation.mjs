import { net, ordered, dateKey, performance } from './core.mjs';

export function riskSnapshot(trades, account, timezone, now = Date.now()) {
  const closed = trades.filter(t => t.exitDate != null && t.exitDate <= now).sort((a, b) => a.exitDate - b.exitDate || a.id.localeCompare(b.id));
  const days = new Map(), entries = new Map(), today = dateKey(now, timezone), rules = account.rules;
  for (const t of closed) { const key = dateKey(t.exitDate, timezone); if (!days.has(key)) days.set(key, []); days.get(key).push(t); }
  for (const t of trades) { const key = dateKey(t.date, timezone); entries.set(key, (entries.get(key) ?? 0) + 1); }
  let balance = account.startingBalance, peak = balance, breach = false;
  const daily = [...days].sort(([a], [b]) => a.localeCompare(b)).map(([day, rows]) => {
    const floor = rules.maximumLoss == null ? null : (rules.drawdownMethod === 'End of day' ? peak : account.startingBalance) - rules.maximumLoss;
    let pnl = 0;
    for (const t of rows) { balance += net(t); pnl += net(t); if (floor != null && balance < floor || rules.dailyLoss != null && pnl < -rules.dailyLoss) breach = true; }
    if (day < today) peak = Math.max(peak, balance);
    return [day, pnl];
  });
  const realized = closed.reduce((sum, t) => sum + net(t), 0), todayPnL = daily.find(([day]) => day === today)?.[1] ?? 0;
  const floor = rules.maximumLoss == null || rules.drawdownMethod === 'Intraday equity' ? null : (rules.drawdownMethod === 'End of day' ? peak : account.startingBalance) - rules.maximumLoss;
  return { balance, realized, today: todayPnL, days: days.size, todayCount: entries.get(today) ?? 0, floor, remaining: floor == null ? null : balance - floor, dailyRemaining: rules.dailyLoss == null ? null : rules.dailyLoss + todayPnL, consistency: realized > 0 ? Math.max(0, ...daily.map(([, pnl]) => pnl)) / realized * 100 : null, unverified: trades.some(t => t.exitDate == null) || rules.drawdownMethod === 'Intraday equity', historicalBreach: breach && rules.drawdownMethod !== 'Intraday equity', oversizedTrades: rules.riskPerTrade == null ? 0 : trades.filter(t => (t.riskDollars ?? 0) > rules.riskPerTrade).length, dailyCountBreaches: rules.dailyTradeCount == null ? 0 : [...entries.values()].filter(n => n > rules.dailyTradeCount).length };
}
export function executions(supplement, direction) {
  let quantity = 0, cost = 0, realized = 0, slippage = 0, compared = 0;
  const sign = direction === 'Long' ? 1 : -1, point = supplement.pointValue;
  if (!(point > 0) || !Number.isFinite(point)) throw new Error('Puan değeri pozitif olmalı.');
  for (const f of [...supplement.fills].sort((a, b) => a.date - b.date)) {
    if (!(f.quantity > 0) || ![f.quantity, f.price, f.fee].every(Number.isFinite) || f.fee < 0) throw new Error('Geçersiz gerçekleşme.');
    if (f.side === 'Entry') { cost += sign * f.price * f.quantity * point + f.fee; quantity += f.quantity; }
    else {
      if (f.side !== 'Exit' || f.quantity > quantity + 1e-9 || quantity <= 0) throw new Error('Çıkış miktarı açık pozisyonu aşıyor.');
      const allocated = cost / quantity * f.quantity;
      realized += sign * f.price * f.quantity * point - allocated - f.fee; cost -= allocated; quantity = Math.max(0, quantity - f.quantity);
    }
    if (f.expectedPrice != null) { if (!Number.isFinite(f.expectedPrice)) throw new Error('Beklenen fiyat geçersiz.'); slippage += sign * (f.side === 'Entry' ? f.price - f.expectedPrice : f.expectedPrice - f.price) * f.quantity * point; compared++; }
  }
  return { realized, openQuantity: quantity, slippageCost: compared ? slippage : null, comparedFills: compared };
}
export function underwater(trades) {
  const rows = ordered(trades); if (!rows.length) return { longestSeconds: 0, ongoing: false };
  let equity = 0, peak = 0, peakDate = rows[0].date, start = null, longest = 0, recovered = null;
  for (const t of rows) { equity += net(t); if (equity >= peak) { if (start != null) { const duration = (t.date - start) / 1000; longest = Math.max(longest, duration); recovered = Math.max(recovered ?? 0, duration); } peak = equity; peakDate = t.date; start = null; } else if (start == null) start = peakDate; }
  if (start != null) longest = Math.max(longest, (rows.at(-1).date - start) / 1000);
  return { longestSeconds: longest, longestRecoveredSeconds: recovered, ongoing: start != null };
}
export function rolling(trades, window = 20) { const rows = ordered(trades); return rows.map((t, i) => ({ date: t.date, ...performance(rows.slice(Math.max(0, i - window + 1), i + 1)) })); }
export function percentile(sorted, p) { if (!sorted.length) return 0; const i = Math.max(0, Math.min(1, p)) * (sorted.length - 1), low = Math.floor(i); return sorted[low] + (sorted[Math.min(low + 1, sorted.length - 1)] - sorted[low]) * (i - low); }
export function simulate(trades, { runs = 500, horizon = 100, shuffle = false, seed = 6 } = {}) {
  if (trades.length < 2 || !Number.isInteger(runs) || runs < 1 || runs > 2000 || !Number.isInteger(horizon) || horizon < 1 || horizon > 1000) return null;
  const outcomes = ordered(trades).map(net); if (!outcomes.every(Number.isFinite)) return null;
  const steps = shuffle ? Math.min(horizon, outcomes.length) : horizon, columns = Array.from({ length: steps + 1 }, () => []), drawdowns = [];
  let state = BigInt(seed), losses = 0;
  const random = bound => { state = BigInt.asUintN(64, state * 6364136223846793005n + 1442695040888963407n); return Number(state * BigInt(bound) >> 64n); };
  for (let run = 0; run < runs; run++) {
    const values = [...outcomes]; if (shuffle) for (let i = values.length - 1; i > 0; i--) { const j = random(i + 1); [values[i], values[j]] = [values[j], values[i]]; }
    let equity = 0, peak = 0, dd = 0; columns[0].push(0);
    for (let step = 0; step < steps; step++) { equity += shuffle ? values[step] : outcomes[random(outcomes.length)]; peak = Math.max(peak, equity); dd = Math.max(dd, peak - equity); columns[step + 1].push(equity); }
    drawdowns.push(dd); if (equity < 0) losses++;
  }
  return { band: columns.map((values, id) => { values.sort((a, b) => a - b); return { id, low: percentile(values, .05), median: percentile(values, .5), high: percentile(values, .95) }; }), drawdowns: drawdowns.sort((a, b) => a - b), lossFraction: losses / runs, runs, horizon: steps };
}
export function nearestPoint(points, date) {
  if (!points.length) return -1;
  function upperBound(target) {
    let low = 0, high = points.length;
    while (low < high) {
      const mid = (low + high) >> 1;
      if (points[mid].date <= target) low = mid + 1;
      else high = mid;
    }
    return low;
  }
  const right = upperBound(date);
  if (right === 0) return upperBound(points[0].date) - 1;
  if (right === points.length) return right - 1;
  const before = points[right - 1], after = points[right];
  return date - before.date < after.date - date ? right - 1 : upperBound(after.date) - 1;
}
