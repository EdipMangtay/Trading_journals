import Papa from 'papaparse';
import { importCSV, instantFromWallTime } from '../shared/core.mjs';
import { esc, header, panel, pick, options, command, tradeRows } from './views.js';

const fields = ['date', 'instrument', 'direction', 'session', 'gross_pnl', 'fees', 'r_multiple', 'risk_dollars', 'setup', 'notes', 'id', 'record_json', 'currency'];
const fingerprint = trade => JSON.stringify([trade.date, trade.instrument.toUpperCase(), trade.direction, trade.grossPnL, trade.fees]);

export async function readCSV(file) {
  if (file.size > 30_000_000) throw new Error('CSV dosyası en çok 30 MB olabilir.');
  const result = Papa.parse(await file.text(), { skipEmptyLines: 'greedy' });
  if (result.errors.length || result.data.length < 2 || result.data.length > 50001) throw new Error('CSV 1–50.000 geçerli veri satırı içermeli.');
  const [columns, ...rows] = result.data;
  if (rows.some(row => row.length !== columns.length)) throw new Error('CSV satırları başlıkla aynı sayıda sütun içermeli.');
  return { name: file.name, columns, rows };
}

export function previewCSV(source, form, data) {
  const mapping = Object.fromEntries(fields.flatMap(key => form.get(key) ? [[key, Number(form.get(key)) - 1]] : []));
  if (!('record_json' in mapping) && !['date', 'instrument', 'gross_pnl'].every(key => key in mapping)) throw new Error('Tarih, enstrüman ve brüt K/Z sütunlarını eşleştir.');
  const zone = data.preferences.timezone;
  const mapped = source.rows.map((row, i) => {
    const record = Object.fromEntries(Object.entries(mapping).map(([key, column]) => [key, row[column].trim()]));
    if (record.currency && record.currency.toUpperCase() !== data.preferences.currency) throw new Error(`Satır ${i + 2}: Para birimi seçili hesapla uyuşmuyor.`);
    if (!record.record_json) {
      if (form.get('dateFormat') === 'local') {
        const match = /^(\d{2})\.(\d{2})\.(\d{4})(?: (\d{2}):(\d{2}))?$/.exec(record.date ?? '');
        if (!match) throw new Error(`Satır ${i + 2}: GG.AA.YYYY SS:dd tarih biçimi gerekli.`);
        record.date = new Date(instantFromWallTime(`${match[3]}-${match[2]}-${match[1]}T${match[4] ?? '00'}:${match[5] ?? '00'}`, zone)).toISOString();
      } else if (!/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:?\d{2})$/i.test(record.date ?? '')) {
        throw new Error(`Satır ${i + 2}: Saat dilimi içeren ISO tarihi gerekli.`);
      }
      record.session ||= form.get('defaultSession');
    }
    return record;
  });
  // Validate each row with the same parser as the existing CSV path.
  const columns = [...Object.keys(mapping), ...('session' in mapping ? [] : ['session'])];
  const records = importCSV(Papa.unparse(mapped, { columns }), data.setups, { allowDuplicateIDs: true });
  const ids = new Set(data.trades.map(t => t.id.toLowerCase())), seen = new Set(data.trades.map(fingerprint));
  return records.map(trade => {
    const key = fingerprint(trade), idCollision = ids.has(trade.id.toLowerCase()), duplicate = idCollision || seen.has(key);
    ids.add(trade.id.toLowerCase()); seen.add(key);
    return { trade, duplicate, idCollision };
  });
}

export function csvPage(data, state) {
  const source = state.csvSource;
  const title = header('DATA / CSV', 'İşlem verilerini içe aktar.', 'Sütunları eşleştir, para birimini doğrula ve kaydetmeden önce işlemleri incele.');
  const file = panel('CSV DOSYASI', '<label>CSV seç<input type="file" id="mapped-csv" accept=".csv,text/csv"></label>' + (source ? `<p>${esc(source.name)} · ${source.rows.length} satır</p>` : ''));
  if (!source) return title + file;
  const columns = source.columns.map((name, i) => [String(i + 1), name]);
  const preview = state.csvPreview;
  return title + file + panel('SÜTUN EŞLEME',
    `<form id="mapping-form"><div class="form-grid">${fields.map(key => {
      const auto = source.columns.findIndex(c => c.trim().toLowerCase() === key) + 1;
      return `<label>${key}<select name="${key}" aria-label="${key}">${options(columns, state.csvMapping?.[key] ?? String(auto), 'Eşleme yok', false)}</select></label>`;
    }).join('')}</div><div class="actions">${pick('dateFormat', 'Tarih biçimi', [['iso', 'ISO 8601'], ['local', 'GG.AA.YYYY SS:dd']], state.csvMapping?.dateFormat ?? 'iso')}
    ${pick('defaultSession', 'Varsayılan seans', data.preferences.sessions, state.csvMapping?.defaultSession ?? data.preferences.sessions[0])}<button type="submit">Önizle</button></div></form>`) +
    (preview ? panel('AKTARIM ÖNİZLEMESİ',
      `<p>${preview.length} işlem · ${preview.filter(item => item.duplicate).length} olası yinelenen kayıt · ${esc(data.preferences.currency)}</p>` +
      tradeRows(preview.slice(0, 12).map(item => item.trade), data, { inert: true }) +
      '<label class="check"><input id="skip-csv-duplicates" type="checkbox" checked>Olası yinelenen kayıtları atla</label>' +
      `<label class="check"><input id="confirm-csv-mapping" type="checkbox">Önizlemeyi ve ${esc(data.preferences.currency)} para birimini onaylıyorum</label>` +
      command('apply-csv-mapping', 'Yeni kayıtları aktar', 'upload', 'class="primary" disabled'), 'İlk 12 satır') : '');
}
