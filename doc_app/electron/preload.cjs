const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  openFileDialog: () => ipcRenderer.invoke('dialog:openFile'),
  saveFileDialog: (data) => ipcRenderer.invoke('dialog:saveFile', data),
  exportPDFDialog: (data) => ipcRenderer.invoke('dialog:exportPDF', data),
  print: () => ipcRenderer.invoke('app:print'),
  minimize: () => ipcRenderer.send('window:minimize'),
  maximize: () => ipcRenderer.send('window:maximize'),
  close: () => ipcRenderer.send('window:close'),
  isMaximized: () => ipcRenderer.invoke('window:isMaximized'),
  isElectron: true
});
