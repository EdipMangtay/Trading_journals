const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('journal', {
  load: () => ipcRenderer.invoke('journal:load'),
  save: value => ipcRenderer.invoke('journal:save', value),
  exportBackup: value => ipcRenderer.invoke('journal:export', value),
  exportLegacyBackup: value => ipcRenderer.invoke('journal:export', value, true),
  importBackup: (value, demo) => ipcRenderer.invoke('journal:import', value, demo),
  exportPDF: () => ipcRenderer.invoke('journal:pdf'),
  exportCSV: value => ipcRenderer.invoke('journal:csv-export', value),
  importCSV: (value, demo) => ipcRenderer.invoke('journal:csv-import', value, demo),
  pickImages: () => ipcRenderer.invoke('journal:images'),
  dropImages: files => ipcRenderer.invoke('journal:drop-images', files),
  renderImage: data => ipcRenderer.invoke('journal:render-image', data),
  dataPath: () => ipcRenderer.invoke('journal:path')
});
