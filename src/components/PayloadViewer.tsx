import { useState } from 'react'

interface Token {
  text: string
  className?: string
}

function tokenizeJson(json: string): Token[] {
  const tokens: Token[] = []
  let i = 0

  while (i < json.length) {
    const ch = json[i]

    // String (including key names and string values)
    if (ch === '"') {
      const start = i
      i++
      while (i < json.length && json[i] !== '"') {
        if (json[i] === '\\' && i + 1 < json.length) i += 2
        else i++
      }
      if (i < json.length) i++ // closing quote
      const text = json.slice(start, i)
      tokens.push({ text, className: 'text-success' })
      continue
    }

    // Number
    if (ch === '-' || (ch >= '0' && ch <= '9')) {
      const start = i
      if (ch === '-') i++
      while (i < json.length && json[i] >= '0' && json[i] <= '9') i++
      if (i < json.length && json[i] === '.') {
        i++
        while (i < json.length && json[i] >= '0' && json[i] <= '9') i++
      }
      const text = json.slice(start, i)
      tokens.push({ text, className: 'text-orange-400' })
      continue
    }

    // Boolean literals
    if (json.slice(i, i + 4) === 'true') {
      tokens.push({ text: 'true', className: 'text-purple-400' })
      i += 4
      continue
    }
    if (json.slice(i, i + 5) === 'false') {
      tokens.push({ text: 'false', className: 'text-purple-400' })
      i += 5
      continue
    }

    // Null literal
    if (json.slice(i, i + 4) === 'null') {
      tokens.push({ text: 'null', className: 'text-text-secondary' })
      i += 4
      continue
    }

    // Colon (separator between key and value) — color preceding token as key if it's a string
    if (ch === ':') {
      // Recolor the last token if it was a string → key color
      const last = tokens[tokens.length - 1]
      if (last && last.className === 'text-success' && !last.text.startsWith(': ')) {
        last.className = 'text-accent'
      }
      tokens.push({ text: ':', className: 'text-text-secondary' })
      i++
      continue
    }

    // Whitespace
    if (/\s/.test(ch)) {
      const start = i
      while (i < json.length && /\s/.test(json[i])) i++
      tokens.push({ text: json.slice(start, i) })
      continue
    }

    // Any other character (brackets, commas, etc.)
    tokens.push({ text: ch, className: 'text-text-secondary' })
    i++
  }

  return tokens
}

interface PayloadViewerProps {
  data: Record<string, unknown>
}

export default function PayloadViewer({ data }: PayloadViewerProps) {
  const [raw] = useState(() => JSON.stringify(data, null, 2))
  const tokens = tokenizeJson(raw)

  return (
    <div className="bg-background border border-border rounded overflow-auto">
      <pre className="text-sm font-mono p-4 whitespace-pre-wrap break-all">
        {tokens.map((token, idx) =>
          token.className ? (
            <span key={idx} className={token.className}>
              {token.text}
            </span>
          ) : (
            <span key={idx}>{token.text}</span>
          )
        )}
      </pre>
    </div>
  )
}
