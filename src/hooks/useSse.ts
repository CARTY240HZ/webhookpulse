import { useState, useEffect, useRef, useCallback } from 'react'
import { supabase } from '../lib/supabase'

export interface SseMessage {
  [key: string]: unknown
}

interface SseCallbacks {
  onMessage?: (data: SseMessage) => void
  onError?: (error: Event) => void
  onConnect?: () => void
}

export function useSse(url: string, callbacks: SseCallbacks = {}) {
  const [connected, setConnected] = useState(false)
  const [lastEvent, setLastEvent] = useState<SseMessage | null>(null)
  const eventSourceRef = useRef<EventSource | null>(null)
  const reconnectTimeoutRef = useRef<ReturnType<typeof setTimeout>>()
  const reconnectAttemptsRef = useRef(0)

  // Stable refs for callbacks — prevents stale closure without needing options in deps
  const onMessageRef = useRef(callbacks.onMessage)
  const onErrorRef = useRef(callbacks.onError)
  const onConnectRef = useRef(callbacks.onConnect)

  onMessageRef.current = callbacks.onMessage
  onErrorRef.current = callbacks.onError
  onConnectRef.current = callbacks.onConnect

  const connect = useCallback(async () => {
    if (eventSourceRef.current) return

    // 1. Get JWT from Supabase session
    const { data: { session } } = await supabase.auth.getSession()
    const jwt = session?.access_token || ''
    if (!jwt) return

    // 2. Extract webhookId from URL (e.g., /api/sse-logs?webhookId=xxx)
    const urlObj = new URL(url, window.location.origin)
    const webhookId = urlObj.searchParams.get('webhookId')
    if (!webhookId) return

    // 3. Handshake: exchange JWT for short-lived SSE token
    const handshakeRes = await fetch('/api/sse-handshake', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${jwt}`,
      },
      body: JSON.stringify({ webhookId }),
    })
    if (!handshakeRes.ok) {
      onErrorRef.current?.(new Event('handshake_failed'))
      return
    }
    const { token: sseToken } = await handshakeRes.json()
    if (!sseToken) return

    // 4. Connect SSE with short-lived token (NOT the Supabase JWT)
    const es = new EventSource(`${url}&token=${encodeURIComponent(sseToken)}`)
    eventSourceRef.current = es

    es.onopen = () => {
      setConnected(true)
      reconnectAttemptsRef.current = 0
      onConnectRef.current?.()
      // Clear token from URL to prevent it appearing in browser history
      if (typeof window !== 'undefined' && window.history?.replaceState) {
        const url = new URL(window.location.href)
        url.searchParams.delete('token')
        window.history.replaceState({}, '', url.toString())
      }
    }

    es.addEventListener('log', (e: MessageEvent) => {
      try {
        const data = JSON.parse(e.data) as SseMessage
        setLastEvent(data)
        onMessageRef.current?.(data)
      } catch {
        // malformed JSON — ignore
      }
    })

    es.onerror = (e) => {
      setConnected(false)
      onErrorRef.current?.(e)
      es.close()
      eventSourceRef.current = null

      // Exponential backoff: max 30s
      reconnectAttemptsRef.current++
      const delay = Math.min(3000 * Math.pow(2, reconnectAttemptsRef.current - 1), 30000)
      reconnectTimeoutRef.current = setTimeout(() => connect(), delay)
    }
  }, [url]) // url is the ONLY dependency — callbacks are via refs

  const disconnect = useCallback(() => {
    if (reconnectTimeoutRef.current) clearTimeout(reconnectTimeoutRef.current)
    eventSourceRef.current?.close()
    eventSourceRef.current = null
    reconnectAttemptsRef.current = 0
    setConnected(false)
  }, [])

  useEffect(() => {
    connect()
    return () => disconnect()
  }, [connect, disconnect])

  return { connected, lastEvent, connect, disconnect }
}
