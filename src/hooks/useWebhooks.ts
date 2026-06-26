import { useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import type { Webhook } from '../types'

const API_BASE = import.meta.env.VITE_API_URL || ''

export function useWebhooks() {
  const [webhooks, setWebhooks] = useState<Webhook[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchWebhooks = useCallback(async () => {
    setLoading(true)
    setError(null)
    const { data: authData } = await supabase.auth.getSession()
    const session = authData?.session
    if (!session) {
      setError('Not authenticated')
      setWebhooks([])
      setLoading(false)
      return
    }
    try {
      const res = await fetch(`${API_BASE}/api/webhooks`, {
        headers: { 'Authorization': `Bearer ${session.access_token}` }
      })
      const data = await res.json()
      if (!res.ok) {
        throw new Error(data.error || 'Failed to fetch webhooks')
      }
      setWebhooks(data.webhooks || [])
    } catch (err) {
      setError((err as Error).message)
      setWebhooks([])
    }
    setLoading(false)
  }, [])

  useEffect(() => {
    fetchWebhooks()
  }, [fetchWebhooks])

  const createWebhook = async (name: string, description?: string, type: 'native' | 'discord' = 'native') => {
    const { data: authData } = await supabase.auth.getSession()
    const session = authData?.session
    if (!session) throw new Error('Not authenticated')

    const res = await fetch(`${API_BASE}/api/webhooks`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session.access_token}`,
      },
      body: JSON.stringify({ name, description, type }),
    })

    const data = await res.json()
    if (!res.ok) {
      throw new Error(data.error || 'Failed to create webhook')
    }

    await fetchWebhooks()
    // Return full response so callers can access native_url, discord_url, token
    return data as Webhook & { native_url: string; discord_url?: string; token?: string }
  }

  const deleteWebhook = async (id: string) => {
    const { error: supaError } = await supabase.from('webhooks').delete().eq('id', id)
    if (supaError) {
      throw new Error(supaError.message)
    }
    await fetchWebhooks()
  }

  const toggleWebhook = async (id: string, isActive: boolean) => {
    const { error: supaError } = await supabase
      .from('webhooks')
      .update({ is_active: !isActive, updated_at: new Date().toISOString() })
      .eq('id', id)
    if (supaError) {
      throw new Error(supaError.message)
    }
    await fetchWebhooks()
  }

  return { webhooks, loading, error, createWebhook, deleteWebhook, toggleWebhook, refresh: fetchWebhooks }
}
