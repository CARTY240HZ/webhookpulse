import { useState, useEffect, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { Webhook, WebhookLog } from '../types'

export interface LogItem {
  id: string
  webhook_id: string
  webhook_name: string
  type: 'native' | 'discord'
  source: string | null
  ip_address: string | null
  created_at: string
  status: 'success' | 'honeypot' | 'rate_limited'
  isNew: boolean
}

const MAX_LOGS = 20

function mapLogToItem(
  log: WebhookLog,
  webhookMap: Map<string, Webhook>,
  isNew = false
): LogItem {
  const webhook = webhookMap.get(log.webhook_id)
  const payload = log.payload || {}
  const type: 'native' | 'discord' =
    webhook?.has_secret && webhook?.discord_url ? 'discord' : 'native'
  const source =
    typeof payload.source === 'string' ? payload.source : null
  const statusRaw =
    typeof payload.status === 'string' ? payload.status : undefined
  const status: LogItem['status'] =
    statusRaw === 'honeypot' || statusRaw === 'rate_limited'
      ? statusRaw
      : 'success'

  return {
    id: log.id,
    webhook_id: log.webhook_id,
    webhook_name: webhook?.name || 'Unknown',
    type,
    source,
    ip_address: log.ip_address || null,
    created_at: log.created_at,
    status,
    isNew,
  }
}

export function useActivityFeed() {
  const [logs, setLogs] = useState<LogItem[]>([])
  const [isPaused, setIsPaused] = useState(false)
  const [isConnected, setIsConnected] = useState(false)
  const isNewTimersRef = useRef<Record<string, ReturnType<typeof setTimeout>>>({})

  useEffect(() => {
    let cancelled = false
    let subscription: ReturnType<typeof supabase.channel> | null = null

    async function init() {
      const { data: authData } = await supabase.auth.getSession()
      const session = authData?.session
      if (!session) return

      const { data: webhookData } = await supabase
        .from('webhooks')
        .select('*')
        .eq('user_id', session.user.id)
        .order('created_at', { ascending: false })

      if (cancelled || !webhookData) return

      const userWebhooks = webhookData as Webhook[]
      const webhookMap = new Map(userWebhooks.map((w) => [w.id, w]))
      const webhookIds = userWebhooks.map((w) => w.id)
      if (webhookIds.length === 0) return

      const { data: logData } = await supabase
        .from('webhook_logs')
        .select('*')
        .in('webhook_id', webhookIds)
        .order('created_at', { ascending: false })
        .limit(MAX_LOGS)

      if (cancelled || !logData) return

      const initialLogs = (logData as WebhookLog[]).map((log) =>
        mapLogToItem(log, webhookMap)
      )
      setLogs(initialLogs)

      subscription = supabase
        .channel(`activity_feed:${session.user.id}`)
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'webhook_logs',
          },
          (payload) => {
            const newLog = payload.new as WebhookLog
            if (!webhookIds.includes(newLog.webhook_id)) return

            const item = mapLogToItem(newLog, webhookMap, true)
            setLogs((prev) => {
              const next = [item, ...prev].slice(0, MAX_LOGS)
              return next
            })

            if (isNewTimersRef.current[item.id]) {
              clearTimeout(isNewTimersRef.current[item.id])
            }
            isNewTimersRef.current[item.id] = setTimeout(() => {
              setLogs((prev) =>
                prev.map((log) =>
                  log.id === item.id ? { ...log, isNew: false } : log
                )
              )
              delete isNewTimersRef.current[item.id]
            }, 3000)
          }
        )
        .subscribe((status) => {
          setIsConnected(status === 'SUBSCRIBED')
        })
    }

    init()

    return () => {
      cancelled = true
      if (subscription) {
        subscription.unsubscribe()
      }
      Object.values(isNewTimersRef.current).forEach((timer) =>
        clearTimeout(timer)
      )
      isNewTimersRef.current = {}
    }
  }, [])

  return { logs, isPaused, setIsPaused, isConnected }
}
