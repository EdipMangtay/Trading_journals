# V6 audit · 2 November 2026

Baseline: `1f78f242a2bc711c062434ad8e31991a6a19a4ba`, recoverable branch `safety/v6-before-20261102`. Working tree initially clean. Online SQLite backup: `macos/build/v6-safety/Journal.store`, integrity_check = ok; external image directory copied. Never commit this private backup. Existing rendered views preserved in `build/v6-before`.

## Capability inventory

| Capability | Initial status | V6 direction |
|---|---|---|
| Trade CRUD, notes, tags, screenshots, annotation layers | Working | Preserve |
| QT/MMXM/PO3/SSMT/TSMO/CRT, HTF, confirmations | Working | Reuse in research |
| Core P&L/R/drawdown/streak/expectancy formulas | Working | No changes |
| Dashboard, equity, R, drawdown, rolling WR, heatmap | Visual improvement | Flagship chart and compact composition |
| Scatter, strategy/group/monthly comparisons | Functional extension | Inspection and drill-down |
| Playbook rules and ideal images | Functional extension | Optional structured checklists |
| Psychology and rule tracking | Working | Cohort analysis |
| Daily/weekly/monthly review | Functional extension | Preparation and PDF |
| CSV/JSON import/export, local snapshots, demo isolation | Working | Mapping and extended backup |
| Search, multidimensional filters | Functional extension | Saved cohorts |
| Account manager / prop risk | Missing, feasible | V2 additive model |
| Fills / partial executions | Missing, feasible | Optional supplemental ledger; manual P&L authoritative |
| Monte Carlo / duration / rolling expectancy | Missing, feasible | Deterministic descriptive analytics |
| Dashboard/table customization | Missing, feasible | Persistent workspace settings |
| Market replay / MAE / MFE | External data required | Deferred until licensed intratrade data |
| AI narrative | Optional dependency | Evaluate only; offline app remains complete |

## Official product research

Research date: 2026-11-02. Vendor claims are not independently verified; no performance or profitability claims adopted.

- [TradeZella features](https://www.tradezella.com/features): linked journal, playbooks, planning and replay. Useful workflow: move from a result to its execution and rules. [Replay documentation](https://help.tradezella.com/en/articles/11787298-what-is-the-trade-replay-feature-in-tradezella-and-how-does-it-compare-to-backtesting) distinguishes actual executions from simulated backtests. We preserve that distinction and defer market replay.
- [TraderSync](https://tradersync.com/): customizable reporting, performance assistant and historical-data replay. Useful direction: cohort inspection and related trades. External AI and broker synchronization are outside this offline iteration.
- [TradesViz](https://www.tradesviz.com/): custom dashboards, trade tables, day/trade plans, psychology and prop compliance tools. Useful direction: saved workspaces and explicit rule calculations; no invented broker presets.
- [Edgewonk](https://edgewonk.com/): chart/psychology labs, reusable plan/review templates and custom journal layouts. Useful direction: structured responses and reusable research, without copying branding or screens.
- [Apple macOS HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos): resizable workspaces, familiar menu/keyboard/sheet patterns. Native controls and existing reduced-motion handling retained.
- [Apple SchemaMigrationPlan](https://developer.apple.com/documentation/swiftdata/schemamigrationplan): explicit ordered schemas and migration stages; use additive V2 instead of rewriting V1 entities.

## Visual audit / intended composition

Actual baseline dashboard inspected: four oversized cards and a discipline banner push the primary curve below the first viewport. Similar boxed treatments flatten hierarchy. Replace with an unboxed numerical ribbon, large primary plot and narrow process rail; secondary charts are optional and ordered. Graphite surfaces become less blue, mint stays semantic. Preserve linear interpolation and true data points. Every baseline screen remains in the browsable local gallery; new captures must be separately marked and inspected.

## Data decisions

Preserve all V1 model definitions. V2 adds one workspace document with typed Codable accounts, explicit trade/account assignments, execution/checklist supplements, saved filters and layout preferences. Unassigned historical IDs resolve to the stable legacy account without rewriting trade payloads. Closed-trade risk calculations use exit timestamps only; absent exits make risk compliance unverified. No FX conversion or mixed-currency P&L summation. New JSON backup version includes the workspace; explicit V1 export warns about excluded macOS extensions. Production app is not replaced and changes are not pushed in this task.
