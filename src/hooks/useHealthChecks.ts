import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'

interface HealthCheck {
  status: string
  responseTimeMs: number
  checkedAt: string
}

const API_BASE = import.meta.env.VITE_API_URL || ''

export function useHealthChecks(webhookId: string | undefined) {
  const [checks, setChecks] = useState<HealthCheck[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const cacheRef = useRef<Record<string, HealthCheck[]>>({})

  const fetchHealthChecks = useCallback(async () => {
    if (!webhookId) {
      setChecks([])
      setLoading(false)
      return
    }

    // Return cached if available
    if (cacheRef.current[webhookId]) {
      setChecks(cacheRef.current[webhookId])
    }

    setLoading(true)
    setError(null)

    const { data: authData } = await supabase.auth.getSession()
    const session = authData?.session
    if (!session) {
      setError('Not authenticated')
      setLoading(false)
      return
    }

    try {
      const res = await fetch(`${API_BASE}/api/health-check?webhookId=${encodeURIComponent(webhookId)}`, {
        headers: { Authorization: `Bearer ${session.access_token}` },
      })
      const data = await res.json()
      if (!res.ok) {
        throw new Error(data.error || 'Failed to fetch health checks')
      }
      const fetched = (data.checks || []) as HealthCheck[]
      cacheRef.current[webhookId] = fetched
      setChecks(fetched)
    } catch (err) {
      setError((err as Error).message)
    }
    setLoading(false)
  }, [webhookId])

  useEffect(() => {
    fetchHealthChecks()
  }, [fetchHealthChecks])

  // Auto-refresh every 60 seconds
  useEffect(() => {
    if (!webhookId) return
    const interval = setInterval(() => {
      fetchHealthChecks()
    }, 60000)
    return () => clearInterval(interval)
  }, [webhookId, fetchHealthChecks])

  const latest = checks.length > 0 ? checks[0] : null

  return { checks, latest, loading, error, refresh: fetchHealthChecks }
}
