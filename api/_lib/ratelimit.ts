import type { SupabaseClient } from '@supabase/supabase-js'

const RATE_LIMIT_WINDOW_MS = 60_000 // 1 minute
const RATE_LIMIT_MAX = 10 // 10 requests per IP per minute

export async function checkRateLimit(supabase: SupabaseClient, ip: string): Promise<boolean> {
  if (!ip) return true

  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MS).toISOString()
  const { count, error } = await supabase
    .from('webhook_logs')
    .select('id', { count: 'exact', head: true })
    .eq('ip_address', ip)
    .gte('created_at', windowStart)

  if (error) return true // fail open on DB error
  return (count || 0) < RATE_LIMIT_MAX
}
