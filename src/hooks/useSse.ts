import { useState, useEffect, useRef, useCallback } from 'react'

interface SseOptions {
  onMessage?: (data: any) => void
  onError?: (error: Event) => void
  onConnect?: () => void
}

export function useSse(url: string, options: SseOptions = {}) {
  const [connected, setConnected] = useState(false)
  const [lastEvent, setLastEvent] = useState<any>(null)
  const eventSourceRef = useRef<EventSource | null>(null)
  const reconnectTimeoutRef = useRef<number>()

  const connect = useCallback(() => {
    if (eventSourceRef.current) return

    const token = localStorage.getItem('token') || ''
    const es = new EventSource(`${url}?token=${encodeURIComponent(token)}`)
    eventSourceRef.current = es

    es.onopen = () => {
      setConnected(true)
      options.onConnect?.()
    }

    es.onmessage = (e) => {
      try {
        const data = JSON.parse(e.data)
        setLastEvent(data)
        options.onMessage?.(data)
      } catch {
        // ignore malformed JSON
      }
    }

    es.onerror = (e) => {
      setConnected(false)
      options.onError?.(e)
      es.close()
      eventSourceRef.current = null
      // Reconnect after 3s
      reconnectTimeoutRef.current = window.setTimeout(connect, 3000)
    }
  }, [url, options])

  const disconnect = useCallback(() => {
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current)
    }
    eventSourceRef.current?.close()
    eventSourceRef.current = null
    setConnected(false)
  }, [])

  useEffect(() => {
    connect()
    return () => disconnect()
  }, [connect, disconnect])

  return { connected, lastEvent, connect, disconnect }
}
