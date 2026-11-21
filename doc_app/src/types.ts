export type MarginType = 'normal' | 'narrow' | 'wide'

export type OrientationType = 'portrait' | 'landscape'

export type ViewModeType = 'page' | 'reading'

export interface DocumentState {
  fileName: string
  filePath: string | null
  isDirty: boolean
  wordCount: number
  charCount: number
  pageCount: number
  readTimeMinutes: number
  zoom: number // 50 to 200 (%)
  marginType: MarginType
  orientation: OrientationType
  viewMode: ViewModeType
}

export interface ElectronAPI {
  openFileDialog: () => Promise<{ name: string; path: string; buffer: Uint8Array | ArrayBuffer } | null>
  saveFileDialog: (data: { defaultName?: string; buffer: Uint8Array | ArrayBuffer }) => Promise<{ success: boolean; filePath?: string; fileName?: string }>
  exportPDFDialog: (data: { defaultName?: string }) => Promise<{ success: boolean; filePath?: string; error?: string }>
  print: () => Promise<void>
  minimize: () => void
  maximize: () => void
  close: () => void
  isMaximized: () => Promise<boolean>
  isElectron: boolean
}

declare global {
  interface Window {
    electronAPI?: ElectronAPI
  }
}
