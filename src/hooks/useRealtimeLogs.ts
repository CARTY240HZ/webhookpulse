import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import type { WebhookLog } from '../types'

export function useRealtimeLogs(webhookId: string | null) {
  const [logs, setLogs] = useState<WebhookLog[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!webhookId) {
      setLogs([])
      setLoading(false)
      return
    }

    setLoading(true)

    const fetchLogs = async () => {
      const { data, error } = await supabase
        .from('webhook_logs')
        .select('*')
        .eq('webhook_id', webhookId)
        .order('created_at', { ascending: false })
        .limit(200)

      if (!error && data) {
        setLogs(data as WebhookLog[])
      }
      setLoading(false)
    }

    fetchLogs()

    const subscription = supabase
      .channel(`webhook_logs:${webhookId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'webhook_logs',
          filter: `webhook_id=eq.${webhookId}`,
        },
        (payload) => {
          setLogs((prev) => [payload.new as WebhookLog, ...prev])
        }
      )
      .subscribe()

    return () => {
      subscription.unsubscribe()
    }
  }, [webhookId])

  return { logs, loading }
}
