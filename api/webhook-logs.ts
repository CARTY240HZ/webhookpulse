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

  if (req.method !== 'GET' && req.method !== 'DELETE') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(supabase, authHeader)
    if (!user) {
      return res.status(401).json({ error: 'Unauthorized' })
    }

    const webhookId = req.query?.webhookId || ''
    if (!webhookId) {
      return res.status(400).json({ error: 'Missing webhookId' })
    }

    const { data: webhook, error: ownerError } = await supabase
      .from('webhooks')
      .select('id')
      .eq('id', webhookId)
      .eq('user_id', user.id)
      .single()

    if (ownerError || !webhook) {
      return res.status(404).json({ error: 'Webhook not found' })
    }

    if (req.method === 'DELETE') {
      const body = req.body || {}
      const logIds = body.logIds || []
      const deleteAll = body.deleteAll === true

      if (deleteAll) {
        const { error: delError } = await supabase
          .from('webhook_logs')
          .delete()
          .eq('webhook_id', webhookId)
        if (delError) {
          return res.status(500).json({ error: 'Failed to delete logs', details: delError.message })
        }
        return res.status(200).json({ success: true, deleted: 'all' })
      }

      if (logIds.length === 0) {
        return res.status(400).json({ error: 'No logIds provided' })
      }

      const { error: delError } = await supabase
        .from('webhook_logs')
        .delete()
        .in('id', logIds)
        .eq('webhook_id', webhookId)
      if (delError) {
        return res.status(500).json({ error: 'Failed to delete logs', details: delError.message })
      }
      return res.status(200).json({ success: true, deleted: logIds.length })
    }

    const { data: logs, error } = await supabase
      .from('webhook_logs')
      .select('*')
      .eq('webhook_id', webhookId)
      .order('created_at', { ascending: false })
      .limit(200)

    if (error) {
      return res.status(500).json({ error: 'Failed to fetch logs', details: error.message })
    }

    return res.status(200).json({ logs: logs || [] })
  } catch (err) {
    return res.status(500).json({ error: 'Internal error', details: (err as Error).message })
  }
}
