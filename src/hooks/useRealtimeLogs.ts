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

  const deleteLog = async (logId: string) => {
    if (!webhookId) return
    const { error } = await supabase
      .from('webhook_logs')
      .delete()
      .eq('id', logId)
      .eq('webhook_id', webhookId)
    if (!error) {
      setLogs((prev) => prev.filter((l) => l.id !== logId))
    }
  }

  const deleteSelectedLogs = async (logIds: string[]) => {
    if (!webhookId || logIds.length === 0) return
    const { error } = await supabase
      .from('webhook_logs')
      .delete()
      .in('id', logIds)
      .eq('webhook_id', webhookId)
    if (!error) {
      setLogs((prev) => prev.filter((l) => !logIds.includes(l.id)))
    }
  }

  const deleteAllLogs = async () => {
    if (!webhookId) return
    const { error } = await supabase
      .from('webhook_logs')
      .delete()
      .eq('webhook_id', webhookId)
    if (!error) {
      setLogs([])
    }
  }

  return { logs, loading, deleteLog, deleteSelectedLogs, deleteAllLogs }
}