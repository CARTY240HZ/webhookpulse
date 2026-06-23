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
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Webhook-Secret',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  }
}

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders())
    return res.status(204).end()
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  try {
    const supabase = getSupabase()
    const path = req.query?.path || ''
    if (!path) {
      return res.status(400).json({ error: 'Missing path parameter' })
    }

    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id, secret, is_active, user_id')
      .eq('url_path', path)
      .single()

    if (findError || !webhook) {
      return res.status(404).json({ error: 'Webhook not found' })
    }

    if (!webhook.is_active) {
      return res.status(403).json({ error: 'Webhook is inactive' })
    }

    const providedSecret = req.headers['x-webhook-secret'] || ''
    if (webhook.secret && providedSecret !== webhook.secret) {
      return res.status(401).json({ error: 'Invalid secret' })
    }

    let payload: unknown = null
    try {
      if (req.body) {
        if (Buffer.isBuffer(req.body)) {
          payload = JSON.parse(req.body.toString('utf-8'))
        } else if (typeof req.body === 'string') {
          payload = JSON.parse(req.body)
        } else {
          payload = req.body
        }
      }
    } catch {
      payload = {}
    }

    const rawIp = req.headers['x-forwarded-for'] || req.headers['client-ip'] || null
    const ipAddress = rawIp ? String(rawIp).split(',')[0].trim() : null

    let insertResult = await supabase
      .from('webhook_logs')
      .insert({
        webhook_id: webhook.id,
        payload: payload ?? {},
        headers: req.headers as Record<string, string>,
        ip_address: ipAddress,
      })
      .select('id')
      .single()

    if (insertResult.error && insertResult.error.message.includes('inet')) {
      insertResult = await supabase
        .from('webhook_logs')
        .insert({
          webhook_id: webhook.id,
          payload: payload ?? {},
          headers: req.headers as Record<string, string>,
          ip_address: null,
        })
        .select('id')
        .single()
    }

    if (insertResult.error) {
      return res.status(500).json({ error: 'Failed to store log', details: insertResult.error.message })
    }

    return res.status(200).json({ success: true, logId: insertResult.data.id })
  } catch (err) {
    return res.status(500).json({ error: 'Internal error', details: (err as Error).message })
  }
}
