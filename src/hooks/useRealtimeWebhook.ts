import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'

export interface RealtimeMessage {
  [key: string]: unknown
}

interface RealtimeCallbacks {
  onMessage?: (data: RealtimeMessage) => void
  onError?: (error: Error) => void
  onConnect?: () => void
}

export function useRealtimeWebhook(webhookId: string | null, callbacks: RealtimeCallbacks = {}) {
  const [connected, setConnected] = useState(false)
  const [lastEvent, setLastEvent] = useState<RealtimeMessage | null>(null)
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null)
  const callbacksRef = useRef(callbacks)
  callbacksRef.current = callbacks

  const connect = useCallback(() => {
    if (!webhookId || channelRef.current) return

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
          const data = payload.new as RealtimeMessage
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
  }, [webhookId])

  const disconnect = useCallback(() => {
    if (channelRef.current) {
      supabase.removeChannel(channelRef.current)
      channelRef.current = null
      setConnected(false)
    }
  }, [])

  useEffect(() => {
    connect()
    return disconnect
  }, [connect, disconnect])

  return { connected, lastEvent, connect, disconnect }
}

// Backward compatibility alias
export function useSse(url: string, callbacks: RealtimeCallbacks = {}) {
  const urlObj = new URL(url, typeof window !== 'undefined' ? window.location.href : '')
  const webhookId = urlObj.searchParams.get('webhookId') || ''
  return useRealtimeWebhook(webhookId || null, callbacks)
}
