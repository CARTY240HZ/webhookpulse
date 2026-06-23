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
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
  }
}

async function getUserFromJWT(supabase: SupabaseClient, authHeader: string) {
  const token = authHeader.replace('Bearer ', '').trim()
  if (!token) return null
  const { data, error } = await supabase.auth.getUser(token)
  if (error || !data.user) return null
  return data.user
}

function escapeCsvCell(value: string): string {
  if (value.includes('"') || value.includes(',') || value.includes('\n') || value.includes('\r')) {
    return '"' + value.replace(/"/g, '""') + '"'
  }
  return value
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

    const { data: logs, error } = await supabase
      .from('webhook_logs')
      .select('id, created_at, ip_address, payload')
      .eq('webhook_id', webhookId)
      .order('created_at', { ascending: false })

    if (error) {
      return res.status(500).json({ error: 'Failed to fetch logs', details: error.message })
    }

    const rows = logs || []
    const headers = ['id', 'created_at', 'source_ip', 'payload_json']
    const csvRows = [headers.join(',')]

    for (const row of rows) {
      const payloadStr = row.payload ? JSON.stringify(row.payload) : ''
      csvRows.push(
        [
          escapeCsvCell(String(row.id)),
          escapeCsvCell(row.created_at ? new Date(row.created_at).toISOString() : ''),
          escapeCsvCell(row.ip_address || ''),
          escapeCsvCell(payloadStr),
        ].join(',')
      )
    }

    const csv = csvRows.join('\r\n')

    res.set({
      ...corsHeaders(),
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="webhook-logs-${webhookId}.csv"`,
    })

    return res.status(200).send(csv)
  } catch (err) {
    return res.status(500).json({ error: 'Internal error', details: (err as Error).message })
  }
}
