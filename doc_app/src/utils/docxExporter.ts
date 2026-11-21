import {
  Document,
  Paragraph,
  TextRun,
  Table,
  TableRow,
  TableCell,
  HeadingLevel,
  AlignmentType,
  WidthType,
  BorderStyle,
  ImageRun,
  Packer,
  PageOrientation
} from 'docx'
import { JSONContent } from '@tiptap/react'
import { MarginType, OrientationType } from '../types'

interface RawRun {
  text: string
  bold?: boolean
  italic?: boolean
  underline?: boolean
  strike?: boolean
  sub?: boolean
  super?: boolean
  color?: string
  highlight?: string
  isBreak?: boolean
}

function base64ToUint8Array(base64: string): Uint8Array {
  const cleanBase64 = base64.replace(/^data:image\/[a-zA-Z0-9+.-]+;base64,/, '')
  const binaryString = typeof window !== 'undefined' && window.atob
    ? window.atob(cleanBase64)
    : Buffer.from(cleanBase64, 'base64').toString('binary')
  const len = binaryString.length
  const bytes = new Uint8Array(len)
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i)
  }
  return bytes
}

function mapAlignment(textAlign?: string): (typeof AlignmentType)[keyof typeof AlignmentType] {
  switch (textAlign) {
    case 'center':
      return AlignmentType.CENTER
    case 'right':
      return AlignmentType.RIGHT
    case 'justify':
      return AlignmentType.JUSTIFIED
    case 'left':
    default:
      return AlignmentType.LEFT
  }
}

function extractRawRuns(nodes?: JSONContent[]): RawRun[] {
  if (!nodes || nodes.length === 0) return []

  const rawRuns: RawRun[] = []

  for (const node of nodes) {
    if (node.type === 'text') {
      const marks = node.marks || []
      const isBold = marks.some((m) => m.type === 'bold')
      const isItalic = marks.some((m) => m.type === 'italic')
      const isUnderline = marks.some((m) => m.type === 'underline')
      const isStrike = marks.some((m) => m.type === 'strike')
      const isSub = marks.some((m) => m.type === 'subscript')
      const isSuper = marks.some((m) => m.type === 'superscript')
      const isHighlight = marks.some((m) => m.type === 'highlight')
      const colorMark = marks.find((m) => m.type === 'textStyle' && m.attrs?.color)
      const color = colorMark?.attrs?.color ? colorMark.attrs.color.replace('#', '') : undefined

      rawRuns.push({
        text: node.text || '',
        bold: isBold,
        italic: isItalic,
        underline: isUnderline,
        strike: isStrike,
        sub: isSub,
        super: isSuper,
        color,
        highlight: isHighlight ? 'yellow' : undefined
      })
    } else if (node.type === 'hardBreak') {
      rawRuns.push({ text: '', isBreak: true })
    }
  }

  return rawRuns
}

function createTextRunsFromRaw(rawRuns: RawRun[], defaultFontSize = 24, forceBold = false, forceColor?: string): TextRun[] {
  return rawRuns.map((r) => {
    if (r.isBreak) {
      return new TextRun({ break: 1 })
    }
    return new TextRun({
      text: r.text,
      bold: forceBold || r.bold,
      italics: r.italic,
      underline: r.underline ? {} : undefined,
      strike: r.strike,
      subScript: r.sub,
      superScript: r.super,
      color: forceColor || r.color,
      highlight: r.highlight as any,
      size: defaultFontSize,
      font: 'Segoe UI'
    })
  })
}

function convertBlockToDocx(node: JSONContent): any[] {
  switch (node.type) {
    case 'heading': {
      const level = node.attrs?.level || 1
      let headingLevel: (typeof HeadingLevel)[keyof typeof HeadingLevel] = HeadingLevel.HEADING_1
      let fontSize = 48 // 24pt
      if (level === 2) {
        headingLevel = HeadingLevel.HEADING_2
        fontSize = 36 // 18pt
      } else if (level === 3) {
        headingLevel = HeadingLevel.HEADING_3
        fontSize = 28 // 14pt
      }

      const raw = extractRawRuns(node.content)
      const runs = createTextRunsFromRaw(raw, fontSize, true, '185ABD')

      return [
        new Paragraph({
          heading: headingLevel,
          alignment: mapAlignment(node.attrs?.textAlign),
          spacing: { before: 240, after: 120 },
          children: runs.length > 0 ? runs : [new TextRun({ text: '', size: fontSize })]
        })
      ]
    }

    case 'paragraph': {
      const raw = extractRawRuns(node.content)
      const runs = createTextRunsFromRaw(raw, 24)
      return [
        new Paragraph({
          alignment: mapAlignment(node.attrs?.textAlign),
          spacing: { line: 276, after: 140 }, // 1.15 line spacing, 7pt space after
          children: runs.length > 0 ? runs : [new TextRun('')]
        })
      ]
    }

    case 'bulletList': {
      const result: Paragraph[] = []
      if (node.content) {
        for (const item of node.content) {
          if (item.type === 'listItem' && item.content) {
            for (const child of item.content) {
              const raw = extractRawRuns(child.content)
              const runs = createTextRunsFromRaw(raw, 24)
              result.push(
                new Paragraph({
                  bullet: { level: 0 },
                  spacing: { line: 276, after: 60 },
                  children: runs
                })
              )
            }
          }
        }
      }
      return result
    }

    case 'orderedList': {
      const result: Paragraph[] = []
      let index = 1
      if (node.content) {
        for (const item of node.content) {
          if (item.type === 'listItem' && item.content) {
            for (const child of item.content) {
              const raw = extractRawRuns(child.content)
              const runs = createTextRunsFromRaw(raw, 24)
              result.push(
                new Paragraph({
                  children: [
                    new TextRun({ text: `${index}. `, bold: true, size: 24, font: 'Segoe UI' }),
                    ...runs
                  ],
                  spacing: { line: 276, after: 60 },
                  indent: { left: 360 }
                })
              )
              index++
            }
          }
        }
      }
      return result
    }

    case 'taskList': {
      const result: Paragraph[] = []
      if (node.content) {
        for (const item of node.content) {
          if (item.type === 'taskItem' && item.content) {
            const checked = item.attrs?.checked ? '☑ ' : '☐ '
            for (const child of item.content) {
              const raw = extractRawRuns(child.content)
              const runs = createTextRunsFromRaw(raw, 24)
              result.push(
                new Paragraph({
                  children: [
                    new TextRun({ text: checked, bold: true, color: '185ABD', size: 24 }),
                    ...runs
                  ],
                  spacing: { line: 276, after: 60 },
                  indent: { left: 360 }
                })
              )
            }
          }
        }
      }
      return result
    }

    case 'blockquote': {
      const result: Paragraph[] = []
      if (node.content) {
        for (const child of node.content) {
          const raw = extractRawRuns(child.content)
          const runs = createTextRunsFromRaw(raw, 24)
          result.push(
            new Paragraph({
              children: runs,
              indent: { left: 720 },
              border: {
                left: { color: '185ABD', space: 10, style: BorderStyle.SINGLE, size: 24 }
              },
              spacing: { before: 120, after: 120, line: 276 }
            })
          )
        }
      }
      return result
    }

    case 'codeBlock': {
      const text = node.content?.map((c) => c.text).join('') || ''
      return [
        new Paragraph({
          children: [
            new TextRun({
              text,
              font: 'Courier New',
              size: 20
            })
          ],
          shading: { fill: 'F3F4F6' },
          spacing: { before: 120, after: 120 },
          indent: { left: 360, right: 360 }
        })
      ]
    }

    case 'horizontalRule': {
      return [
        new Paragraph({
          border: {
            bottom: { color: 'D1D5DB', space: 1, style: BorderStyle.SINGLE, size: 6 }
          },
          spacing: { before: 180, after: 180 }
        })
      ]
    }

    case 'table': {
      const rows: TableRow[] = []
      if (node.content) {
        for (const rowNode of node.content) {
          if (rowNode.type === 'tableRow' && rowNode.content) {
            const cells: TableCell[] = []
            for (const cellNode of rowNode.content) {
              const isHeader = cellNode.type === 'tableHeader'
              const cellParagraphs: Paragraph[] = []

              if (cellNode.content) {
                for (const pNode of cellNode.content) {
                  const raw = extractRawRuns(pNode.content)
                  const runs = createTextRunsFromRaw(raw, 22, isHeader)
                  cellParagraphs.push(
                    new Paragraph({
                      children: runs.length > 0 ? runs : [new TextRun('')],
                      alignment: mapAlignment(pNode.attrs?.textAlign)
                    })
                  )
                }
              }

              if (cellParagraphs.length === 0) {
                cellParagraphs.push(new Paragraph({ children: [new TextRun('')] }))
              }

              cells.push(
                new TableCell({
                  children: cellParagraphs,
                  shading: isHeader ? { fill: 'EBF3FC' } : undefined,
                  margins: { top: 120, bottom: 120, left: 180, right: 180 },
                  borders: {
                    top: { style: BorderStyle.SINGLE, size: 4, color: 'D1D5DB' },
                    bottom: { style: BorderStyle.SINGLE, size: 4, color: 'D1D5DB' },
                    left: { style: BorderStyle.SINGLE, size: 4, color: 'D1D5DB' },
                    right: { style: BorderStyle.SINGLE, size: 4, color: 'D1D5DB' }
                  }
                })
              )
            }
            rows.push(new TableRow({ children: cells }))
          }
        }
      }

      return [
        new Table({
          width: { size: 100, type: WidthType.PERCENTAGE },
          rows
        })
      ]
    }

    case 'image': {
      try {
        const src = node.attrs?.src
        if (src && src.startsWith('data:image')) {
          const uint8 = base64ToUint8Array(src)
          const isJpg = src.startsWith('data:image/jpeg') || src.startsWith('data:image/jpg')
          return [
            new Paragraph({
              children: [
                new ImageRun({
                  data: uint8,
                  type: isJpg ? 'jpg' : 'png',
                  transformation: {
                    width: 500,
                    height: 300
                  }
                })
              ],
              alignment: AlignmentType.CENTER,
              spacing: { before: 180, after: 180 }
            })
          ]
        }
      } catch (err) {
        console.error('Failed to encode image to docx:', err)
      }
      return []
    }

    default:
      return []
  }
}

export function exportTipTapToDocxDocument(
  docJSON: JSONContent,
  marginType: MarginType = 'normal',
  orientation: OrientationType = 'portrait'
): Document {
  // Margin settings in twips (1 inch = 1440 twips)
  let marginConfig = { top: 1440, right: 1440, bottom: 1440, left: 1440 }
  if (marginType === 'narrow') {
    marginConfig = { top: 720, right: 720, bottom: 720, left: 720 }
  } else if (marginType === 'wide') {
    marginConfig = { top: 2160, right: 2160, bottom: 2160, left: 2160 }
  }

  // Page dimensions for A4 in twips: 210mm x 297mm -> 11906 x 16838 twips
  const isLandscape = orientation === 'landscape'
  const pageWidth = isLandscape ? 16838 : 11906
  const pageHeight = isLandscape ? 11906 : 16838

  const children: any[] = []

  if (docJSON && docJSON.content) {
    for (const block of docJSON.content) {
      const docxBlocks = convertBlockToDocx(block)
      children.push(...docxBlocks)
    }
  }

  if (children.length === 0) {
    children.push(new Paragraph({ text: '' }))
  }

  return new Document({
    sections: [
      {
        properties: {
          page: {
            size: {
              orientation: isLandscape ? PageOrientation.LANDSCAPE : PageOrientation.PORTRAIT,
              width: pageWidth,
              height: pageHeight
            },
            margin: marginConfig
          }
        },
        children
      }
    ]
  })
}

export async function exportTipTapToArrayBuffer(
  docJSON: JSONContent,
  marginType: MarginType = 'normal',
  orientation: OrientationType = 'portrait'
): Promise<ArrayBuffer> {
  const doc = exportTipTapToDocxDocument(docJSON, marginType, orientation)
  return await Packer.toArrayBuffer(doc)
}

export async function exportTipTapToBlob(
  docJSON: JSONContent,
  marginType: MarginType = 'normal',
  orientation: OrientationType = 'portrait'
): Promise<Blob> {
  const doc = exportTipTapToDocxDocument(docJSON, marginType, orientation)
  return await Packer.toBlob(doc)
}
