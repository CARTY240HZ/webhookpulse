import { useState } from 'react'
import { ChevronDown, ChevronUp } from 'lucide-react'
import type { WebhookLog } from '../types'
import PayloadViewer from './PayloadViewer'
import RobloxEmbed from './RobloxEmbed'

interface LogRowProps {
  log: WebhookLog
}

export default function LogRow({ log }: LogRowProps) {
  const [expanded, setExpanded] = useState(false)
  const timestamp = new Date(log.created_at).toLocaleString()

  const isRoblox = log.payload?.source === 'roblox'
  const previewText = isRoblox
    ? `Roblox: ${log.payload.username || 'unknown'} (UID: ${log.payload.userid || '-'})`
    : JSON.stringify(log.payload).substring(0, 80)
  const previewTruncated = isRoblox
    ? false
    : JSON.stringify(log.payload).length > 80

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
        <span className={`text-sm truncate ${isRoblox ? 'text-accent' : 'text-text-primary'}`}>
          {previewText}
          {previewTruncated ? '...' : ''}
        </span>
      </button>
      {expanded && (
        <div className="px-4 pb-4 space-y-3">
          {isRoblox && <RobloxEmbed log={log} />}
          <div>
            <div className="text-xs text-text-secondary uppercase tracking-wider font-semibold mb-1">
              {isRoblox ? 'Raw Payload' : 'Payload'}
            </div>
            <PayloadViewer data={log.payload} />
          </div>
        </div>
      )}
    </div>
  )
}
