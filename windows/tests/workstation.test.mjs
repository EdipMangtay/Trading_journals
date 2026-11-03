import { test } from 'node:test';
import assert from 'node:assert/strict';
import { emptyJournal, newTrade, parseBackup, mergeBackup } from '../shared/core.mjs';
import { accountFor, defaultWorkspace, legacyAccountID, portableBackup, scopedTrades, withWorkspace } from '../shared/workspace-state.mjs';
import { executions, nearestPoint, riskSnapshot, simulate } from '../shared/workstation.mjs';

test('V1 records migrate in place and a V2 backup preserves accounts, executions and unrelated trades', () => {
  const existing = emptyJournal(), first = newTrade(), second = newTrade();
  existing.trades = [first];
  const upgraded = withWorkspace(existing);
  assert.equal(accountFor(upgraded, first.id), legacyAccountID);
  assert.deepEqual(scopedTrades(upgraded), [first]);

  const incoming = withWorkspace({ ...emptyJournal(), trades: [second] });
  const account = { id: crypto.randomUUID(), name: 'Test account', currency: 'EUR', startingBalance: 25000, rules: {} };
  incoming.workspace.accounts.push(account);
  incoming.workspace.assignments[second.id] = account.id;
  incoming.workspace.supplements[second.id] = { fills: [], checklist: [], pointValue: 5, tickSize: .25 };
  incoming.workspace.selectedAccountID = account.id;

  const archive = portableBackup(incoming);
  assert.equal(archive.version, 2);
  assert.deepEqual(archive.workspace.assignments, [second.id, account.id]);
  const restored = mergeBackup(upgraded, archive);
  assert.deepEqual(restored.trades.map(t => t.id), [first.id, second.id]);
  assert.equal(restored.workspace.supplements[second.id].pointValue, 5);
  assert.equal(accountFor(restored, first.id), legacyAccountID);
  assert.deepEqual(scopedTrades(restored).map(t => t.id), [second.id]);
  assert.throws(() => parseBackup({ ...archive, trades: [] }), /bulunmayan bir işleme/);
});

test('risk uses closing day, keeps historical breaches and leaves intraday equity unverified', () => {
  const account = defaultWorkspace(emptyJournal().preferences).accounts[0];
  account.rules = { maximumLoss: 500, dailyLoss: 300, drawdownMethod: 'End of day' };
  const now = Date.parse('2026-10-03T12:00:00Z');
  const trade = (entry, exit, pnl) => ({ ...newTrade(undefined, Date.parse(entry)), exitDate: exit ? Date.parse(exit) : undefined, grossPnL: pnl });
  const trades = [
    trade('2026-10-01T09:00:00Z', '2026-10-01T16:00:00Z', 1000),
    trade('2026-10-01T21:00:00Z', '2026-10-02T10:00:00Z', -600),
    trade('2026-10-03T08:00:00Z', '2026-10-03T10:00:00Z', 400),
    trade('2026-10-03T09:00:00Z', null, 900)
  ];
  const result = riskSnapshot(trades, account, 'UTC', now);
  assert.equal(result.realized, 800);
  assert.equal(result.floor, 50500);
  assert.equal(result.today, 400);
  assert.equal(result.days, 3);
  assert.equal(result.todayCount, 2);
  assert.equal(result.historicalBreach, true);
  assert.equal(result.unverified, true);
  account.rules.drawdownMethod = 'Intraday equity';
  assert.equal(riskSnapshot(trades, account, 'UTC', now).floor, null);
});

test('partial fills allocate entry fees, and excess exits cannot be saved', () => {
  const entry = { date: 1, side: 'Entry', quantity: 2, price: 100, fee: 2 };
  const exit = { date: 2, side: 'Exit', quantity: 1, price: 110, fee: 1, expectedPrice: 111 };
  const supplement = { pointValue: 5, fills: [entry, exit] };
  assert.deepEqual(executions(supplement, 'Long'), { realized: 48, openQuantity: 1, slippageCost: 5, comparedFills: 1 });
  assert.throws(() => executions({ ...supplement, fills: [entry, { ...exit, quantity: 3 }] }, 'Long'), /aşıyor/);
});

test('simulation has a deterministic bounded percentile band and selection returns a recorded observation', () => {
  const rows = [-300, 100, 600].map((grossPnL, i) => ({ ...newTrade(undefined, i + 1), grossPnL }));
  const options = { runs: 100, horizon: 20 };
  const result = simulate(rows, options);
  assert.deepEqual(result, simulate(rows, options));
  assert.equal(result.band.length, 21);
  assert.deepEqual(result.band[0], { id: 0, low: 0, median: 0, high: 0 });
  assert.ok(result.band.every(p => p.low <= p.median && p.median <= p.high));
  assert.equal(simulate(rows, { ...options, shuffle: true }).horizon, 3);
  assert.equal(nearestPoint([{ date: 10 }, { date: 20 }, { date: 20 }, { date: 40 }], 19), 2);
});
