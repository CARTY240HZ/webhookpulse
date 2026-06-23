import { createClient, SupabaseClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.SUPABASE_URL || ''
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY || ''

function getSupabase(): SupabaseClient {
  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_KEY')
  }
  return createClient(supabaseUrl, supabaseServiceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  }
}

async function getUserFromJWT(supabase: SupabaseClient, authHeader: string) {
  const token = authHeader.replace('Bearer ', '').trim()
  if (!token) return null
  const { data, error } = await supabase.auth.getUser(token)
  if (error || !data.user) return null
  return data.user
}

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders())
    return res.status(204).end()
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(supabase, authHeader)
    if (!user) {
      return res.status(401).json({ error: 'Unauthorized' })
    }

    const { data: webhooks, error } = await supabase
      .from('webhooks')
      .select('*, webhook_logs(count)')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })

    if (error) {
      return res.status(500).json({ error: 'Failed to fetch webhooks', details: error.message })
    }

    const enriched = (webhooks || []).map((w: Record<string, unknown>) => ({
      ...w,
      log_count: (w.webhook_logs as { count: number }[])?.[0]?.count ?? 0,
    }))

    return res.status(200).json({ webhooks: enriched })
  } catch (err) {
    return res.status(500).json({ error: 'Internal error', details: (err as Error).message })
  }
}
