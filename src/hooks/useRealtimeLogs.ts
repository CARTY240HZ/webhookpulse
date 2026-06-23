import { useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import type { WebhookLog } from '../types'

const PAGE_SIZE = 50

export function useRealtimeLogs(webhookId: string | null) {
  const [logs, setLogs] = useState<WebhookLog[]>([])
  const [loading, setLoading] = useState(true)
  const [loadingMore, setLoadingMore] = useState(false)
  const [hasMore, setHasMore] = useState(true)
  const [page, setPage] = useState(1)

  const fetchLogs = useCallback(async (pageNum: number, append: boolean) => {
    if (!webhookId) return

    const from = (pageNum - 1) * PAGE_SIZE
    const to = from + PAGE_SIZE - 1

    const { data, error } = await supabase
      .from('webhook_logs')
      .select('*')
      .eq('webhook_id', webhookId)
      .order('created_at', { ascending: false })
      .range(from, to)

    if (!error && data) {
      const newLogs = data as WebhookLog[]
      if (append) {
        setLogs((prev) => [...prev, ...newLogs])
      } else {
        setLogs(newLogs)
      }
      setHasMore(newLogs.length === PAGE_SIZE)
    }
  }, [webhookId])

  useEffect(() => {
    if (!webhookId) {
      setLogs([])
      setLoading(false)
      setHasMore(true)
      setPage(1)
      return
    }

    setLoading(true)
    setPage(1)

    fetchLogs(1, false).then(() => setLoading(false))

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
  }, [webhookId, fetchLogs])

  const loadMore = async () => {
    if (loadingMore || !hasMore) return
    setLoadingMore(true)
    const nextPage = page + 1
    await fetchLogs(nextPage, true)
    setPage(nextPage)
    setLoadingMore(false)
  }

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
      setHasMore(false)
    }
  }

  return { logs, loading, loadingMore, hasMore, loadMore, deleteLog, deleteSelectedLogs, deleteAllLogs }
}
