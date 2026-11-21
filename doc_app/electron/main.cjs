const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 840,
    minWidth: 800,
    minHeight: 600,
    frame: false, // Custom Word 365 TitleBar
    title: 'PC Word 365 Editor',
    icon: path.join(__dirname, 'icon.ico'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  mainWindow.setMenuBarVisibility(false);

  const isDev = process.env.NODE_ENV === 'development' || !app.isPackaged;
  const devUrl = 'http://localhost:5173';

  if (isDev && process.argv.includes('--dev')) {
    mainWindow.loadURL(devUrl);
  } else {
    const indexPath = path.join(__dirname, '../dist/index.html');
    if (fs.existsSync(indexPath)) {
      mainWindow.loadFile(indexPath);
    } else {
      mainWindow.loadURL(devUrl);
    }
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// IPC Handlers
ipcMain.handle('dialog:openFile', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openFile'],
    filters: [
      { name: 'Word Documents', extensions: ['docx'] },
      { name: 'All Files', extensions: ['*'] }
    ]
  });

  if (result.canceled || result.filePaths.length === 0) {
    return null;
  }

  const filePath = result.filePaths[0];
  const fileBuffer = fs.readFileSync(filePath);
  const fileName = path.basename(filePath);

  return {
    name: fileName,
    path: filePath,
    buffer: fileBuffer
  };
});

ipcMain.handle('dialog:saveFile', async (event, { defaultName, buffer }) => {
  const result = await dialog.showSaveDialog(mainWindow, {
    defaultPath: defaultName || 'Document1.docx',
    filters: [
      { name: 'Word Document (.docx)', extensions: ['docx'] }
    ]
  });

  if (result.canceled || !result.filePath) {
    return { success: false };
  }

  fs.writeFileSync(result.filePath, Buffer.from(buffer));
  return { success: true, filePath: result.filePath, fileName: path.basename(result.filePath) };
});

ipcMain.handle('dialog:exportPDF', async (event, { defaultName }) => {
  const result = await dialog.showSaveDialog(mainWindow, {
    defaultPath: defaultName || 'Document1.pdf',
    filters: [
      { name: 'PDF Document (.pdf)', extensions: ['pdf'] }
    ]
  });

  if (result.canceled || !result.filePath) {
    return { success: false };
  }

  try {
    const data = await mainWindow.webContents.printToPDF({
      printBackground: true,
      pageSize: 'A4',
      margins: {
        marginType: 'default'
      }
    });
    fs.writeFileSync(result.filePath, data);
    return { success: true, filePath: result.filePath };
  } catch (err) {
    return { success: false, error: err.message };
  }
});

ipcMain.handle('app:print', async () => {
  if (!mainWindow) return;
  mainWindow.webContents.print({ silent: false, printBackground: true });
});

ipcMain.on('window:minimize', () => {
  if (mainWindow) mainWindow.minimize();
});

ipcMain.on('window:maximize', () => {
  if (mainWindow) {
    if (mainWindow.isMaximized()) {
      mainWindow.unmaximize();
    } else {
      mainWindow.maximize();
    }
  }
});

ipcMain.on('window:close', () => {
  if (mainWindow) mainWindow.close();
});

ipcMain.handle('window:isMaximized', () => {
  return mainWindow ? mainWindow.isMaximized() : false;
});

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
