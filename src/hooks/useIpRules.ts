import { useState, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { IpRule } from '../types'

export function useIpRules(webhookId: string | null) {
  const [rules, setRules] = useState<IpRule[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const fetchedRef = useRef(false)

  const fetchRules = useCallback(async () => {
    if (!webhookId) return
    setLoading(true)
    setError(null)
    try {
      const { data: sessionData } = await supabase.auth.getSession()
      const token = sessionData.session?.access_token
      if (!token) {
        setError('Session expired')
        return
      }
      const baseUrl = typeof window !== 'undefined' ? window.location.origin : ''
      const res = await fetch(`${baseUrl}/api/webhook-ip-rules?webhookId=${webhookId}`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (!res.ok) {
        const err = await res.json().catch(() => ({ error: 'Failed to fetch IP rules' }))
        setError(err.error || 'Failed to fetch IP rules')
        return
      }
      const data = await res.json()
      setRules(data.rules || [])
      fetchedRef.current = true
    } catch {
      setError('Network error')
    } finally {
      setLoading(false)
    }
  }, [webhookId])

  const addRule = useCallback(
    async (ip: string, action: 'allow' | 'block', description?: string) => {
      if (!webhookId) return false
      setError(null)
      try {
        const { data: sessionData } = await supabase.auth.getSession()
        const token = sessionData.session?.access_token
        if (!token) {
          setError('Session expired')
          return false
        }
        const baseUrl = typeof window !== 'undefined' ? window.location.origin : ''
        const res = await fetch(`${baseUrl}/api/webhook-ip-rules`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({ webhookId, ip, action, description }),
        })
        if (!res.ok) {
          const err = await res.json().catch(() => ({ error: 'Failed to add IP rule' }))
          setError(err.error || 'Failed to add IP rule')
          return false
        }
        const data = await res.json()
        setRules((prev) => [data.rule, ...prev])
        return true
      } catch {
        setError('Network error')
        return false
      }
    },
    [webhookId]
  )

  const deleteRule = useCallback(
    async (ruleId: string) => {
      if (!webhookId) return false
      setError(null)
      try {
        const { data: sessionData } = await supabase.auth.getSession()
        const token = sessionData.session?.access_token
        if (!token) {
          setError('Session expired')
          return false
        }
        const baseUrl = typeof window !== 'undefined' ? window.location.origin : ''
        const res = await fetch(`${baseUrl}/api/webhook-ip-rules`, {
          method: 'DELETE',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({ ruleId }),
        })
        if (!res.ok) {
          const err = await res.json().catch(() => ({ error: 'Failed to delete IP rule' }))
          setError(err.error || 'Failed to delete IP rule')
          return false
        }
        setRules((prev) => prev.filter((r) => r.id !== ruleId))
        return true
      } catch {
        setError('Network error')
        return false
      }
    },
    [webhookId]
  )

  return { rules, loading, error, fetchRules, addRule, deleteRule }
}
