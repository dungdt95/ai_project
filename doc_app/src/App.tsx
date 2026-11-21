import React, { useState, useEffect, useRef } from 'react'
import { useEditor } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Table from '@tiptap/extension-table'
import TableRow from '@tiptap/extension-table-row'
import TableCell from '@tiptap/extension-table-cell'
import TableHeader from '@tiptap/extension-table-header'
import Image from '@tiptap/extension-image'
import TextAlign from '@tiptap/extension-text-align'
import TextStyle from '@tiptap/extension-text-style'
import { Color } from '@tiptap/extension-color'
import Highlight from '@tiptap/extension-highlight'
import Underline from '@tiptap/extension-underline'
import Subscript from '@tiptap/extension-subscript'
import Superscript from '@tiptap/extension-superscript'
import Link from '@tiptap/extension-link'
import TaskList from '@tiptap/extension-task-list'
import TaskItem from '@tiptap/extension-task-item'
import { saveAs } from 'file-saver'

import { TitleBar } from './components/TitleBar'
import { RibbonToolbar } from './components/RibbonToolbar'
import { EditorCanvas } from './components/EditorCanvas'
import { StatusBar } from './components/StatusBar'
import { defaultDocumentHTML } from './utils/sampleDocument'
import { importDocxToArrayBuffer, importDocxFile } from './utils/docxImporter'
import { exportTipTapToArrayBuffer, exportTipTapToBlob } from './utils/docxExporter'
import { MarginType, OrientationType, ViewModeType } from './types'

export const App: React.FC = () => {
  const [fileName, setFileName] = useState('Document1.docx')
  const [filePath, setFilePath] = useState<string | null>(null)
  const [isDirty, setIsDirty] = useState(false)
  const [marginType, setMarginType] = useState<MarginType>('normal')
  const [orientation, setOrientation] = useState<OrientationType>('portrait')
  const [viewMode, setViewMode] = useState<ViewModeType>('page')
  const [zoom, setZoom] = useState(100)

  const [wordCount, setWordCount] = useState(0)
  const [charCount, setCharCount] = useState(0)
  const [pageCount, setPageCount] = useState(1)
  const [readTimeMinutes, setReadTimeMinutes] = useState(1)

  const fileInputRef = useRef<HTMLInputElement>(null)

  const editor = useEditor({
    extensions: [
      StarterKit.configure({
        heading: {
          levels: [1, 2, 3]
        }
      }),
      Table.configure({
        resizable: true
      }),
      TableRow,
      TableHeader,
      TableCell,
      Image.configure({
        inline: false,
        allowBase64: true
      }),
      TextAlign.configure({
        types: ['heading', 'paragraph']
      }),
      TextStyle,
      Color,
      Highlight.configure({
        multicolor: true
      }),
      Underline,
      Subscript,
      Superscript,
      Link.configure({
        openOnClick: false
      }),
      TaskList,
      TaskItem.configure({
        nested: true
      })
    ],
    content: defaultDocumentHTML,
    onUpdate: ({ editor }) => {
      setIsDirty(true)
      updateStats(editor.getText())
    }
  })

  const updateStats = (text: string) => {
    const trimmed = text.trim()
    const words = trimmed ? trimmed.split(/\s+/).filter(Boolean).length : 0
    const chars = text.length
    const pages = Math.max(1, Math.ceil(words / 350))
    const readTime = Math.max(1, Math.ceil(words / 200))

    setWordCount(words)
    setCharCount(chars)
    setPageCount(pages)
    setReadTimeMinutes(readTime)
  }

  useEffect(() => {
    if (editor) {
      updateStats(editor.getText())
    }
  }, [editor])

  // New Document
  const handleNew = () => {
    if (isDirty) {
      const confirmNew = window.confirm('Tài liệu hiện tại có thay đổi chưa lưu. Bạn có muốn tạo tài liệu mới không?')
      if (!confirmNew) return
    }
    editor?.commands.setContent('<h1>Tài liệu mới</h1><p>Bắt đầu nhập nội dung văn bản của bạn tại đây...</p>')
    setFileName('Document1.docx')
    setFilePath(null)
    setIsDirty(false)
  }

  // Open Document (via Dialog)
  const handleOpen = async () => {
    if (window.electronAPI?.openFileDialog) {
      const fileData = await window.electronAPI.openFileDialog()
      if (fileData) {
        try {
          const result = await importDocxToArrayBuffer(fileData.buffer)
          editor?.commands.setContent(result.html)
          setFileName(fileData.name)
          setFilePath(fileData.path)
          setIsDirty(false)
        } catch (err: any) {
          alert('Không thể mở tệp .docx: ' + (err.message || err))
        }
      }
    } else {
      // Browser fallback
      fileInputRef.current?.click()
    }
  }

  // Open via Web File Input
  const handleWebFileInput = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      await loadFile(file)
    }
    e.target.value = ''
  }

  // Common file loading (used by Web input & Drag-and-Drop)
  const loadFile = async (file: File) => {
    try {
      const result = await importDocxFile(file)
      editor?.commands.setContent(result.html)
      setFileName(file.name)
      setFilePath(null)
      setIsDirty(false)
    } catch (err: any) {
      alert('Lỗi đọc tệp .docx: ' + (err.message || err))
    }
  }

  // Save Document (.docx OpenXML)
  const handleSave = async () => {
    if (!editor) return

    try {
      const docJSON = editor.getJSON()

      if (window.electronAPI?.saveFileDialog) {
        const arrayBuffer = await exportTipTapToArrayBuffer(docJSON, marginType, orientation)
        const res = await window.electronAPI.saveFileDialog({
          defaultName: fileName,
          buffer: arrayBuffer
        })
        if (res.success && res.fileName) {
          setFileName(res.fileName)
          setFilePath(res.filePath || null)
          setIsDirty(false)
        }
      } else {
        // Web browser download
        const blob = await exportTipTapToBlob(docJSON, marginType, orientation)
        saveAs(blob, fileName.endsWith('.docx') ? fileName : `${fileName}.docx`)
        setIsDirty(false)
      }
    } catch (err: any) {
      alert('Lỗi khi lưu tệp Word: ' + (err.message || err))
    }
  }

  // Print / Export PDF
  const handlePrint = async () => {
    if (window.electronAPI?.exportPDFDialog) {
      const pdfName = fileName.replace(/\.docx$/i, '') + '.pdf'
      const res = await window.electronAPI.exportPDFDialog({ defaultName: pdfName })
      if (!res.success && res.error) {
        alert('Lỗi xuất PDF: ' + res.error)
      }
    } else {
      window.print()
    }
  }

  // Keyboard Shortcuts handler
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && !e.altKey) {
        switch (e.key.toLowerCase()) {
          case 's':
            e.preventDefault()
            handleSave()
            break
          case 'o':
            e.preventDefault()
            handleOpen()
            break
          case 'p':
            e.preventDefault()
            handlePrint()
            break
          case 'n':
            e.preventDefault()
            handleNew()
            break
          case 'l':
            e.preventDefault()
            editor?.chain().focus().setTextAlign('left').run()
            break
          case 'e':
            e.preventDefault()
            editor?.chain().focus().setTextAlign('center').run()
            break
          case 'r':
            e.preventDefault()
            editor?.chain().focus().setTextAlign('right').run()
            break
          case 'j':
            e.preventDefault()
            editor?.chain().focus().setTextAlign('justify').run()
            break
        }
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [editor, fileName, marginType, orientation, isDirty])

  return (
    <div className="app-container">
      {/* Hidden File Input for browser mode */}
      <input
        type="file"
        ref={fileInputRef}
        style={{ display: 'none' }}
        accept=".docx"
        onChange={handleWebFileInput}
      />

      {/* TitleBar & Quick Access */}
      <TitleBar
        fileName={fileName}
        isDirty={isDirty}
        canUndo={editor?.can().undo() ?? false}
        canRedo={editor?.can().redo() ?? false}
        onNew={handleNew}
        onOpen={handleOpen}
        onSave={handleSave}
        onPrint={handlePrint}
        onUndo={() => editor?.chain().focus().undo().run()}
        onRedo={() => editor?.chain().focus().redo().run()}
      />

      {/* Ribbon Toolbar */}
      <RibbonToolbar
        editor={editor}
        marginType={marginType}
        orientation={orientation}
        viewMode={viewMode}
        zoom={zoom}
        onMarginChange={setMarginType}
        onOrientationChange={setOrientation}
        onViewModeChange={setViewMode}
        onZoomChange={setZoom}
      />

      {/* Document Page Canvas */}
      <EditorCanvas
        editor={editor}
        zoom={zoom}
        marginType={marginType}
        orientation={orientation}
        viewMode={viewMode}
        onFileDrop={loadFile}
      />

      {/* Status Bar */}
      <StatusBar
        wordCount={wordCount}
        charCount={charCount}
        pageCount={pageCount}
        readTimeMinutes={readTimeMinutes}
        isDirty={isDirty}
        zoom={zoom}
        onZoomChange={setZoom}
      />
    </div>
  )
}

export default App
