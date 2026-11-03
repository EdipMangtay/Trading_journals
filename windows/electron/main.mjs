import { t as tr } from '../shared/i18n.mjs';
import { app, BrowserWindow, dialog, ipcMain, session, Menu } from 'electron';
import { promises as fs, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { imagePipeline, loadImage, validateImages } from './images.mjs';
import { JournalStorage } from './storage.mjs';
import { legacyBackup, portableBackup, withWorkspace } from '../shared/workspace-state.mjs';
import { parseBackup, mergeBackup, exportCSV, importCSV } from '../shared/core.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
app.setName('Liquidity Edge');
let startupError;
try {
  const directory = process.env.JOURNAL_TEST_DATA_DIR
    ? path.resolve(process.env.JOURNAL_TEST_DATA_DIR)
    : path.join(app.getPath('appData'), 'Liquidity Edge');
  mkdirSync(directory, { recursive: true });
  app.setPath('userData', directory);
} catch (error) { startupError = error; }
if (startupError) {
  dialog.showErrorBox(tr("Liquidity Edge could not start"), `The journal folder could not be opened. Your existing files have not been changed.\n\n${startupError.message}`);
  app.quit();
} else if (!app.requestSingleInstanceLock()) app.quit();
else {
  let window;
  app.on('second-instance', () => { if (window) { if (window.isMinimized()) window.restore(); window.focus(); } });
  app.whenReady().then(async () => {
    const storage = new JournalStorage(app.getPath('userData'), validateImages);
    app.on('before-quit', event => {
      if (storage.pendingWrites) {
        event.preventDefault();
        void storage.queue.then(() => app.quit());
      }
    });
    const index = path.join(root, '../dist/index.html');
    const allowedURL = pathToFileURL(index).href;
    window = new BrowserWindow({ width: 1440, height: 960, minWidth: 800, minHeight: 600, title: 'LIQUIDITY EDGE', backgroundColor: '#101215', icon: path.join(root, '../assets/icon.png'),
      webPreferences: { preload: path.join(root, 'preload.cjs'), contextIsolation: true, nodeIntegration: false, sandbox: true, webSecurity: true } });
    Menu.setApplicationMenu(null);
    session.defaultSession.setPermissionRequestHandler((_contents, _permission, callback) => callback(false));
    session.defaultSession.setPermissionCheckHandler(() => false);
    window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
    window.webContents.on('will-navigate', event => event.preventDefault());
    const handle = (name, action) => ipcMain.handle(name, async (event, ...args) => {
      if (event.sender !== window.webContents || event.senderFrame !== window.webContents.mainFrame || event.senderFrame.url !== allowedURL) throw new Error('Untrusted request.');
      return action(...args);
    });
    const readLimited = async filename => {
      if ((await fs.stat(filename)).size > 512000000) throw new Error(tr("File exceeds the 512 MB import limit."));
      return fs.readFile(filename, 'utf8');
    };
    handle('journal:load', () => storage.read());
    handle('journal:path', () => storage.file);
    handle('journal:save', value => storage.write(value));
    handle('journal:export', async (value, legacy = false) => {
      const backup = value ? await validateImages(parseBackup(value)) : await storage.read();
      const { canceled, filePath } = await dialog.showSaveDialog(window, { defaultPath: `LiquidityEdge-${new Date().toISOString().slice(0, 10)}.json`, filters: [{ name: tr("Journal backup"), extensions: ['json'] }] });
      if (canceled) return false;
      const archive = legacy ? legacyBackup(backup) : portableBackup(backup);
      await fs.writeFile(filePath, JSON.stringify({ ...archive, createdAt: Date.now() }, null, 2)); return true;
    });
    handle('journal:import', async (value, demo = false) => {
      const { canceled, filePaths } = await dialog.showOpenDialog(window, { properties: ['openFile'], filters: [{ name: tr("Journal backup"), extensions: ['json'] }] });
      if (canceled) return null;
      const incoming = await validateImages(parseBackup(JSON.parse(await readLimited(filePaths[0]))));
      const { response } = await dialog.showMessageBox(window, { type: 'question', title: tr("Import backup"), message: tr(`Merge ${incoming.trades.length} trades, ${incoming.setups.length} setups and ${incoming.reviews.length} reviews?`), detail: tr("Matching IDs will be replaced. Unrelated records remain. Imported preferences will be applied."), buttons: [tr("Cancel"), tr("Import")], defaultId: 0, cancelId: 0 });
      if (response !== 1) return null;
      if (demo) return mergeBackup(parseBackup(value), incoming);
      let current;
      try { current = await storage.read(); }
      catch {
        const result = await dialog.showMessageBox(window, { type: 'warning', message: tr("The current journal is unreadable. Restore this validated backup?"), detail: tr("The unreadable original will be preserved in journal.json.bak."), buttons: [tr("Cancel"), tr("Restore")], defaultId: 0, cancelId: 0 });
        if (result.response !== 1) return null;
        return storage.write(incoming);
      }
      return storage.write(mergeBackup(current, incoming));
    });
    handle('journal:pdf', async () => {
      const { canceled, filePath } = await dialog.showSaveDialog(window, {
        defaultPath: 'LiquidityEdge-rapor.pdf', filters: [{ name: 'PDF', extensions: ['pdf'] }]
      });
      if (canceled) return false;
      const pdf = await window.webContents.printToPDF({ printBackground: true, pageSize: 'A4' });
      await fs.writeFile(filePath, pdf);
      return true;
    });
    handle('journal:csv-export', async value => {
      const backup = value ? parseBackup(value) : await storage.read();
      const { canceled, filePath } = await dialog.showSaveDialog(window, { defaultPath: 'LiquidityEdge-trades.csv', filters: [{ name: 'CSV', extensions: ['csv'] }] });
      if (canceled) return false;
      await fs.writeFile(filePath, exportCSV(legacyBackup(backup).trades)); return true;
    });
    handle('journal:csv-import', async (value, demo = false) => {
      const { canceled, filePaths } = await dialog.showOpenDialog(window, { properties: ['openFile'], filters: [{ name: 'CSV', extensions: ['csv'] }] });
      if (canceled) return null;
      const current = withWorkspace(demo ? parseBackup(value) : await storage.read()), records = importCSV(await readLimited(filePaths[0]), current.setups);
      const result = await dialog.showMessageBox(window, { type: 'question', message: tr(`Import ${records.length} trades?`), buttons: [tr("Cancel"), tr("Import")], defaultId: 0, cancelId: 0 });
      if (result.response !== 1) return null;
      const byID = new Map(current.trades.map(t => [t.id.toLowerCase(), t]));
      for (const trade of records) {
        const key = trade.id.toLowerCase();
        if (!byID.has(key)) current.workspace.assignments[key] = current.workspace.selectedAccountID;
        byID.set(key, trade);
      }
      const merged = parseBackup({ ...current, trades: [...byID.values()] });
      return demo ? merged : storage.write(merged);
    });
    handle('journal:images', async () => {
      const { canceled, filePaths } = await dialog.showOpenDialog(window, { properties: ['openFile', 'multiSelections'], filters: [{ name: tr("Images"), extensions: ['png', 'jpg', 'jpeg', 'heic', 'heif', 'tif', 'tiff', 'webp'] }] });
      if (canceled) return [];
      if (filePaths.length > 20) throw new Error(tr("Choose at most 20 images at a time."));
      return Promise.all(filePaths.map(async filename => {
        if ((await fs.stat(filename)).size > 30000000) throw new Error(tr("Images must be smaller than 30 MB."));
        return loadImage(filename, await fs.readFile(filename));
      }));
    });
    handle('journal:drop-images', async files => {
      if (!Array.isArray(files) || files.length > 20) throw new Error(tr("Choose at most 20 images at a time."));
      const images = [];
      for (const file of files) images.push(await loadImage(file.name, Buffer.from(file.bytes)));
      return images;
    });
    handle('journal:render-image', async data => {
      if (typeof data !== 'string' || data.length > 40000000) throw new Error(tr("Invalid image."));
      const pipeline = await imagePipeline(Buffer.from(data, 'base64'));
      return (await pipeline.png().toBuffer()).toString('base64');
    });
    await window.loadFile(index);
  }).catch(error => { dialog.showErrorBox(tr("Liquidity Edge could not start"), error.message); app.quit(); });
  app.on('window-all-closed', () => app.quit());
}
