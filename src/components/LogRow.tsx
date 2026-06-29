import { useState, useMemo } from 'react'
import { ChevronDown, ChevronUp, Trash2 } from 'lucide-react'
import type { WebhookLog } from '../types'
import PayloadViewer from './PayloadViewer'
import RobloxEmbed from './RobloxEmbed'
import { Button } from '../components/ui'

interface LogRowProps {
  log: WebhookLog
  selected?: boolean
  onSelect?: (id: string, selected: boolean) => void
  onDelete?: (id: string) => void
}

export default function LogRow({ log, selected, onSelect, onDelete }: LogRowProps) {
  const [expanded, setExpanded] = useState(false)
  const timestamp = new Date(log.created_at).toLocaleString()

  const { isRoblox, previewText, previewTruncated } = useMemo(() => {
    const isRoblox = log.payload?.source === 'roblox'
    const player = log.payload?.player as Record<string, unknown> | undefined
    const username = player?.username ?? log.payload?.username
    const userid = player?.userid ?? log.payload?.userid
    const payloadString = JSON.stringify(log.payload)
    const previewText = isRoblox
      ? `Roblox: ${String(username || '-')} (UID: ${String(userid || '-')})`
      : payloadString.substring(0, 80)
    const previewTruncated = isRoblox ? false : payloadString.length > 80
    return { isRoblox, previewText, previewTruncated }
  }, [log.payload])

  return (
    <div className="border-b border-border last:border-b-0">
      {/* Siempre mostrar embed para Roblox, sin necesidad de expandir */}
      {isRoblox && (
        <div className="px-4 pt-3">
          <RobloxEmbed log={log} />
        </div>
      )}
      
      <div className="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-elevated transition-colors">
        <input
          type="checkbox"
          checked={selected || false}
          onChange={(e) => onSelect?.(log.id, e.target.checked)}
          className="w-4 h-4 rounded border-border bg-background text-accent focus:ring-accent shrink-0"
          aria-label="Select log"
        />
        <button
          onClick={() => setExpanded(!expanded)}
          className="flex items-center gap-3 flex-1 text-left"
          aria-expanded={expanded}
          aria-label="Toggle log details"
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
          <Button onClick={() => onDelete(log.id)} variant="ghost" size="sm" className="shrink-0 text-text-secondary hover:text-danger p-1"
            title="Delete log"
            aria-label="Delete log"
          >
            <Trash2 className="w-4 h-4" />
          </Button>
        )}
      </div>
      
      {/* Non-Roblox: show payload on expand. Roblox: raw JSON on expand */}
      {expanded && (
        <div className="px-4 pb-4 space-y-3">
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
