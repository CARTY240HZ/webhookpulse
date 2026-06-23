import { useState } from 'react'
import { ChevronDown, ChevronUp } from 'lucide-react'
import type { WebhookLog } from '../types'
import PayloadViewer from './PayloadViewer'

interface LogRowProps {
  log: WebhookLog
}

export default function LogRow({ log }: LogRowProps) {
  const [expanded, setExpanded] = useState(false)
  const timestamp = new Date(log.created_at).toLocaleString()

  return (
    <div className="border-b border-border last:border-b-0">
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full flex items-center gap-4 px-4 py-3 text-left hover:bg-elevated transition-colors"
      >
        {expanded ? (
          <ChevronUp className="w-4 h-4 text-text-secondary shrink-0" />
        ) : (
          <ChevronDown className="w-4 h-4 text-text-secondary shrink-0" />
        )}
        <span className="text-sm text-text-secondary w-40 shrink-0">{timestamp}</span>
        <span className="text-sm text-text-secondary w-28 shrink-0">{log.ip_address || 'Unknown IP'}</span>
        <span className="text-sm text-text-primary truncate">
          {JSON.stringify(log.payload).substring(0, 80)}
          {JSON.stringify(log.payload).length > 80 ? '...' : ''}
        </span>
      </button>
      {expanded && (
        <div className="px-4 pb-4">
          <PayloadViewer data={log.payload} />
        </div>
      )}
    </div>
  )
}
