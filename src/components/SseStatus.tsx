import { useRealtimeWebhook } from '../hooks/useRealtimeWebhook'
import { Radio } from 'lucide-react'

interface SseStatusProps {
  webhookId: string
}

export default function SseStatus({ webhookId }: SseStatusProps) {
  const { connected, lastEvent } = useRealtimeWebhook(webhookId)

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
