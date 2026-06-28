import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { WebhookLog } from '../types'

const PAGE_SIZE = 50

export interface LogFilters {
  q?: string
  ip?: string
  from?: string
  to?: string
  source?: string
  type?: 'native' | 'discord' | 'all'
}

function buildFilterQuery(filters: LogFilters): string {
  const params = new URLSearchParams()
  if (filters.q) params.set('q', filters.q)
  if (filters.ip) params.set('ip', filters.ip)
  if (filters.from) params.set('from', filters.from)
  if (filters.to) params.set('to', filters.to)
  if (filters.source) params.set('source', filters.source)
  if (filters.type && filters.type !== 'all') params.set('type', filters.type)
  return params.toString()
}

function logMatchesFilters(log: WebhookLog, filters: LogFilters, webhookType?: 'native' | 'discord'): boolean {
  if (filters.q) {
    const payloadText = JSON.stringify(log.payload).toLowerCase()
    if (!payloadText.includes(filters.q.toLowerCase())) return false
  }
  if (filters.ip && log.ip_address !== filters.ip) return false
  if (filters.from && log.created_at < filters.from) return false
  if (filters.to && log.created_at > filters.to) return false
  if (filters.source && log.payload?.source !== filters.source) return false
  if (filters.type && filters.type !== 'all' && filters.type !== webhookType) return false
  return true
}

function getActiveFilterCount(filters: LogFilters): number {
  let count = 0
  if (filters.q) count++
  if (filters.ip) count++
  if (filters.from) count++
  if (filters.to) count++
  if (filters.source) count++
  if (filters.type && filters.type !== 'all') count++
  return count
}

export function useRealtimeLogs(webhookId: string | null, webhookType?: 'native' | 'discord') {
  const [logs, setLogs] = useState<WebhookLog[]>([])
  const [loading, setLoading] = useState(true)
  const [loadingMore, setLoadingMore] = useState(false)
  const [hasMore, setHasMore] = useState(true)
  const [page, setPage] = useState(1)
  const [filters, setFilters] = useState<LogFilters>({})
  const [totalCount, setTotalCount] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const filtersRef = useRef(filters)

  filtersRef.current = filters

  const hasActiveFilters = getActiveFilterCount(filters) > 0

  const fetchLogs = useCallback(async (pageNum: number, append: boolean) => {
    if (!webhookId) return
    setError(null)

    try {
      const currentFilters = filtersRef.current
      const activeFilterCount = getActiveFilterCount(currentFilters)

      if (activeFilterCount > 0) {
        // Use backend API for filtered queries
        const { data: sessionData } = await supabase.auth.getSession()
        const token = sessionData.session?.access_token
        if (!token) return

        const baseUrl = typeof window !== 'undefined' ? window.location.origin : ''
        const query = buildFilterQuery(currentFilters)
        const res = await fetch(
          `${baseUrl}/api/webhook-logs?webhookId=${webhookId}&page=${pageNum}&limit=${PAGE_SIZE}&${query}`,
          { headers: { Authorization: `Bearer ${token}` } }
        )
        if (!res.ok) {
          const errData = await res.json().catch(() => ({ error: 'Failed to fetch logs' }))
          throw new Error(errData.error || 'Failed to fetch logs')
        }
        const data = await res.json()
        const newLogs = (data.logs || []) as WebhookLog[]
        const total = data.total || 0
        if (append) {
          setLogs((prev) => [...prev, ...newLogs])
        } else {
          setLogs(newLogs)
        }
        setHasMore((pageNum - 1) * PAGE_SIZE + newLogs.length < total)
        setTotalCount(total)
      } else {
        // Use direct Supabase query for unfiltered queries
        const from = (pageNum - 1) * PAGE_SIZE
        const to = from + PAGE_SIZE - 1

        const { data, error } = await supabase
          .from('webhook_logs')
          .select('*')
          .eq('webhook_id', webhookId)
          .order('created_at', { ascending: false })
          .range(from, to)

        if (error) throw new Error(error.message)
        if (data) {
          const newLogs = data as WebhookLog[]
          if (append) {
            setLogs((prev) => [...prev, ...newLogs])
          } else {
            setLogs(newLogs)
          }
          setHasMore(newLogs.length === PAGE_SIZE)
          setTotalCount(0)
        }
      }
    } catch (err: any) {
      console.error('fetchLogs error:', err)
      setError(err.message || 'Failed to fetch logs')
      if (!append) {
        setLogs([])
        setHasMore(false)
      }
    }
  }, [webhookId])

  useEffect(() => {
    if (!webhookId) {
      setLogs([])
      setLoading(false)
      setHasMore(true)
      setPage(1)
      setTotalCount(0)
      setError(null)
      return
    }

    setLoading(true)
    setError(null)
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
          const newLog = payload.new as WebhookLog
          const currentFilters = filtersRef.current
          if (logMatchesFilters(newLog, currentFilters, webhookType)) {
            setLogs((prev) => [newLog, ...prev])
          }
        }
      )
      .subscribe()

    return () => {
      subscription.unsubscribe()
    }
  }, [webhookId, fetchLogs, webhookType, JSON.stringify(filters)])

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
      setTotalCount((prev) => Math.max(0, prev - 1))
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
      setTotalCount((prev) => Math.max(0, prev - logIds.length))
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
      setTotalCount(0)
    }
  }

  const activeFilterCount = getActiveFilterCount(filters)

  return {
    logs,
    loading,
    loadingMore,
    hasMore,
    loadMore,
    deleteLog,
    deleteSelectedLogs,
    deleteAllLogs,
    filters,
    setFilters,
    activeFilterCount,
    totalCount,
    hasActiveFilters,
    error,
  }
}
