import { useSse } from '../hooks/useSse'
import { Radio } from 'lucide-react'

interface SseStatusProps {
  webhookId: string
}

export default function SseStatus({ webhookId }: SseStatusProps) {
  const baseUrl = typeof window !== 'undefined' ? window.location.origin : ''
  const { connected, lastEvent } = useSse(`${baseUrl}/api/sse-logs?webhookId=${webhookId}`, {
    onMessage: (data) => {
      // eslint-disable-next-line no-console
      console.debug('[SSE] New log event:', data)
    },
    onError: (e) => {
      // eslint-disable-next-line no-console
      console.warn('[SSE] Connection error:', e)
    },
  })

  return (
    <div className="flex items-center gap-2 text-xs text-text-secondary">
      <Radio className={`w-3.5 h-3.5 ${connected ? 'text-success' : 'text-danger'}`} />
      <span>{connected ? 'Live' : 'Disconnected'}</span>
      {lastEvent?.event === 'log' && (
        <span className="text-accent">• New log</span>
      )}
    </div>
  )
}
