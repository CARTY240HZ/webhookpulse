import { useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import type { Webhook } from '../types'

export function useWebhooks() {
  const [webhooks, setWebhooks] = useState<Webhook[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchWebhooks = useCallback(async () => {
    setLoading(true)
    setError(null)
    const { data, error: supaError } = await supabase
      .from('webhooks')
      .select('*, webhook_logs(count)')
      .order('created_at', { ascending: false })

    if (supaError) {
      setError(supaError.message)
      setWebhooks([])
    } else {
      const enriched = (data || []).map((w: Record<string, unknown>) => ({
        ...w,
        log_count: (w.webhook_logs as { count: number }[])?.[0]?.count ?? 0,
      })) as Webhook[]
      setWebhooks(enriched)
    }
    setLoading(false)
  }, [])

  useEffect(() => {
    fetchWebhooks()
  }, [fetchWebhooks])

  const createWebhook = async (name: string, description?: string, secret?: string) => {
    const { data, error: supaError } = await supabase
      .from('webhooks')
      .insert({ name, description: description || null, secret: secret || null })
      .select('*')
      .single()

    if (supaError) {
      throw new Error(supaError.message)
    }
    await fetchWebhooks()
    return data as Webhook
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
