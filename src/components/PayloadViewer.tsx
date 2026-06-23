import { useState } from 'react'
import type { WebhookLog } from '../types'

interface PayloadViewerProps {
  data: Record<string, unknown>
}

function syntaxHighlight(json: string): string {
  return json
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/(".*?")(\s*:\s*)/g, '<span class="text-accent">$1</span><span class="text-text-secondary">$2</span>')
    .replace(/: (".*?")/g, ': <span class="text-success">$1</span>')
    .replace(/: (-?\d+(?:\.\d+)?)/g, ': <span class="text-orange-400">$1</span>')
    .replace(/: (true|false)/g, ': <span class="text-purple-400">$1</span>')
    .replace(/: (null)/g, ': <span class="text-text-secondary">$1</span>')
}

export default function PayloadViewer({ data }: PayloadViewerProps) {
  const [raw] = useState(() => JSON.stringify(data, null, 2))

  return (
    <div className="bg-background border border-border rounded overflow-auto">
      <pre
        className="text-sm font-mono p-4 whitespace-pre-wrap break-all"
        dangerouslySetInnerHTML={{ __html: syntaxHighlight(raw) }}
      />
    </div>
  )
}
