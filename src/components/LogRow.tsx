import { useState } from 'react'
import { ChevronDown, ChevronUp, Trash2 } from 'lucide-react'
import type { WebhookLog } from '../types'
import PayloadViewer from './PayloadViewer'
import RobloxEmbed from './RobloxEmbed'

interface LogRowProps {
  log: WebhookLog
  selected?: boolean
  onSelect?: (id: string, selected: boolean) => void
  onDelete?: (id: string) => void
}

export default function LogRow({ log, selected, onSelect, onDelete }: LogRowProps) {
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
      <div className="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-elevated transition-colors">
        <input
          type="checkbox"
          checked={selected || false}
          onChange={(e) => onSelect?.(log.id, e.target.checked)}
          className="w-4 h-4 rounded border-border bg-background text-accent focus:ring-accent shrink-0"
        />
        <button
          onClick={() => setExpanded(!expanded)}
          className="flex items-center gap-3 flex-1 text-left"
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
        {onDelete && (
          <button
            onClick={() => onDelete(log.id)}
            className="shrink-0 text-text-secondary hover:text-danger transition-colors"
            title="Delete log"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        )}
      </div>
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
