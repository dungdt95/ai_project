import * as mammoth from 'mammoth'

export interface ImportResult {
  html: string
  messages: string[]
}

/**
 * Converts a Word (.docx) ArrayBuffer or Uint8Array into HTML suitable for TipTap Editor
 */
export async function importDocxToArrayBuffer(buffer: ArrayBuffer | Uint8Array): Promise<ImportResult> {
  const arrayBuffer: ArrayBuffer = buffer instanceof ArrayBuffer
    ? buffer
    : (buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength) as ArrayBuffer)

  const options = {
    convertImage: mammoth.images.imgElement((element) => {
      return element.read('base64').then((imageBuffer) => {
        return {
          src: `data:${element.contentType};base64,${imageBuffer}`
        }
      })
    })
  }

  const result = await mammoth.convertToHtml({ arrayBuffer, buffer: arrayBuffer } as any, options)
  return {
    html: result.value,
    messages: result.messages.map((m) => m.message)
  }
}

/**
 * Handles File object from Drag and Drop or <input type="file">
 */
export async function importDocxFile(file: File): Promise<ImportResult> {
  const arrayBuffer = await file.arrayBuffer()
  return importDocxToArrayBuffer(arrayBuffer)
}
