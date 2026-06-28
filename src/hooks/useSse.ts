import { useState, useEffect, useRef } from 'react'
import { supabase } from '../lib/supabase'

export interface SseMessage {
  [key: string]: unknown
}

interface SseCallbacks {
  onMessage?: (data: SseMessage) => void
  onError?: (error: Error) => void
  onConnect?: () => void
}

export function useSse(_url: string, callbacks: SseCallbacks = {}) {
  const [connected, setConnected] = useState(false)
  const [lastEvent, setLastEvent] = useState<SseMessage | null>(null)
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null)
  const callbacksRef = useRef(callbacks)
  callbacksRef.current = callbacks

  useEffect(() => {
    // Extract webhookId from the URL (e.g. /api/sse-logs?webhookId=xxx)
    const urlObj = new URL(_url, window.location.origin)
    const webhookId = urlObj.searchParams.get('webhookId')
    if (!webhookId) return

    const channel = supabase
      .channel(`webhook-logs-${webhookId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'webhook_logs',
          filter: `webhook_id=eq.${webhookId}`,
        },
        (payload: any) => {
          const data = payload.new as SseMessage
          setLastEvent(data)
          callbacksRef.current.onMessage?.(data)
        }
      )
      .subscribe((status: string) => {
        if (status === 'SUBSCRIBED') {
          setConnected(true)
          callbacksRef.current.onConnect?.()
        } else if (status === 'CLOSED' || status === 'CHANNEL_ERROR') {
          setConnected(false)
          callbacksRef.current.onError?.(new Error(`Realtime ${status}`))
        }
      })

    channelRef.current = channel

    return () => {
      supabase.removeChannel(channel)
      channelRef.current = null
      setConnected(false)
    }
  }, [_url])

  return { connected, lastEvent, connect: () => {}, disconnect: () => {} }
}
